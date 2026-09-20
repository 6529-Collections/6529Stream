// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StaticArtistLineageFixture } from "./StreamStaticArtistLineage.t.sol";
import {
    StreamStaticArtistLineageSource as Source
} from "../../../smart-contracts/domains/metadata/StreamStaticArtistLineageSource.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Literal immutable-catalogue parity, distinct from actual Artist migration authority.
contract StreamStaticArtistLineageCatalogueTest is StaticArtistLineageFixture {
    function _literalEntry(uint256 index) private view returns (Source.Entry memory e) {
        e.coordinator = address(coordinators[index]);
        e.coordinatorHash = e.coordinator.codehash;
        e.finality = coordinators[index].finalityRegistry();
        e.finalityHash = e.finality.codehash;
        e.provider = coordinators[index].finalityEvidenceProvider();
        e.providerHash = e.provider.codehash;
        // The fixture's constructor independently spells the original Coordinator preimage.
        e.configurationHash = coordinators[index].configurationHash();
        e.suite = suites[index];
        for (uint256 i; i < 7; ++i) {
            e.runtimes[i] = e.suite.owners[i].codehash;
        }
        e.runtimes[7] = e.suite.registry.codehash;
        e.runtimes[8] = e.suite.archive.codehash;
        e.runtimes[9] = e.suite.core.codehash;
        e.runtimes[10] = e.suite.mintManager.codehash;
        e.runtimes[11] = e.suite.roleRegistry.codehash;
        e.runtimes[12] = e.suite.metadata.codehash;
        e.runtimes[13] = e.suite.primaryResolver.codehash;
        e.runtimes[14] = e.suite.royaltyResolver.codehash;
        e.runtimes[15] = e.suite.validator.codehash;
    }

    function _literal() private view returns (Source.Entry[] memory entries, bytes32 folded) {
        entries = new Source.Entry[](3);
        folded = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_ARTIST_LINEAGE_CATALOGUE_V1"),
                block.chainid,
                address(core),
                address(router)
            )
        );
        for (uint256 i; i < 3; ++i) {
            entries[i] = _literalEntry(i);
            require(abi.encode(entries[i]).length == 1280, "complete forty-word entry");
            folded = keccak256(abi.encode(folded, entries[i]));
        }
    }

    function testLiteralCompleteCarrierAndOriginalCatalogueCommitment() public view {
        (Source.Entry[] memory entries, bytes32 folded) = _literal();
        bytes memory expected = bytes.concat(hex"00", abi.encode(entries));
        address carrier = source.catalogueCarrier();
        require(carrier.code.length == 65 + 3 * 1280, "exact compiler-created data image");
        require(keccak256(carrier.code) == keccak256(expected), "all bytes and ABI offsets");
        require(source.catalogueCarrierCodeHash() == keccak256(expected), "immutable runtime pin");
        require(source.catalogueCount() == 3 && source.catalogueHash() == folded, "old domain/fold");
        require(
            carrier
                == address(
                    uint160(
                        uint256(keccak256(abi.encodePacked(hex"d694", address(source), uint8(1))))
                    )
                ),
            "actual Source CREATE child"
        );
        for (uint256 i; i < 3; ++i) {
            require(
                keccak256(abi.encode(source.catalogueEntry(i)))
                    == keccak256(abi.encode(entries[i])),
                "complete entry parity"
            );
            require(
                keccak256(abi.encode(source.catalogueSuite(i))) == keccak256(abi.encode(suites[i])),
                "complete suite parity"
            );
        }
    }

    function testRuntimeMutationRefusesEvenUnusedEntryThenExactRestore() public {
        address carrier = source.catalogueCarrier();
        bytes memory saved = carrier.code;
        bytes memory wrong = bytes.concat(saved);
        // Selected A cannot accept a mutation to C's final field or an altered prefix.
        wrong[wrong.length - 1] = bytes1(uint8(wrong[wrong.length - 1]) ^ 1);
        lvm.etch(carrier, wrong);
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.currentSuite();
        lvm.etch(carrier, saved);
        require(source.currentSuite().registry == suites[0].registry, "exact restoration");
        wrong = bytes.concat(saved);
        wrong[0] = hex"01";
        lvm.etch(carrier, wrong);
        lvm.expectRevert(Source.InvalidStaticArtistLineage.selector);
        source.catalogueEntry(0);
        lvm.etch(carrier, saved);
        _prepare(1, 255, 255);
        _prepare(2, 255, 255);
        require(source.currentSuite().registry == suites[2].registry, "same C request succeeds");
    }

    function testCatalogueAndHistoryRemainExactAcrossCurrentAuthorityChanges() public {
        (Source.Entry[] memory entries, bytes32 folded) = _literal();
        bytes32 image = source.catalogueCarrier().codehash;
        for (uint256 i; i < 3; ++i) {
            if (i != 0) _prepare(i, 255, 255);
            require(
                keccak256(abi.encode(source.currentSuite())) == keccak256(abi.encode(suites[i])),
                "current full suite"
            );
            require(
                source.catalogueHash() == folded && source.catalogueCarrier().codehash == image,
                "no mutable cache"
            );
            for (uint256 j; j < 3; ++j) {
                require(
                    keccak256(abi.encode(source.catalogueEntry(j)))
                        == keccak256(abi.encode(entries[j])),
                    "original full historical entry"
                );
            }
        }
    }

    function testBothOriginalArraySelectorsKeepExactOutOfRangePanic() public view {
        bytes memory expected =
            abi.encodeWithSelector(bytes4(keccak256("Panic(uint256)")), uint256(0x32));
        (bool a, bytes memory ar) = address(source)
            .staticcall(abi.encodeWithSignature("catalogueEntry(uint256)", uint256(3)));
        (bool b, bytes memory br) = address(source)
            .staticcall(abi.encodeWithSignature("catalogueSuite(uint256)", type(uint256).max));
        require(
            !a && !b && keccak256(ar) == keccak256(expected)
                && keccak256(br) == keccak256(expected),
            "original bounds error bytes"
        );
    }

    function testFuzzEveryValidIndexReturnsAllFields(uint8 value) public view {
        uint256 index = uint256(value) % 3;
        Source.Entry memory expected = _literalEntry(index);
        require(
            keccak256(abi.encode(source.catalogueEntry(index))) == keccak256(abi.encode(expected)),
            "literal complete entry"
        );
    }
}
