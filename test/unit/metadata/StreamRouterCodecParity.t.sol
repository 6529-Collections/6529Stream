// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StaticMetadataRoutingFixture } from "../../helpers/StaticMetadataRoutingFixture.sol";
import { RouterCodecReference } from "../../helpers/RouterCodecReference.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    IStreamArtistAttribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamScopedContentRootPublication as Scoped
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamMetadataServingFacts as Facts
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Exact raw input/refusal and read-return parity against the pre-codec method bodies.
/// @dev Typed Core/Artist/admission boundaries are inherited. Temporary reference code is used
/// only inside reverted snapshots to compare decoders at the same address/storage/caller.
/// No runtime-size, current-stack deployment or transitive STATIC acceptance is inferred.
contract StreamRouterCodecParityTest is StaticMetadataRoutingFixture {
    bytes private referenceCode;

    function setUp() public override {
        super.setUp();
        _activate();
        _mint();
        referenceCode =
        address(
            new RouterCodecReference(
                address(core),
                address(executor),
                keccak256("deployment"),
                "ipfs://router",
                keccak256("manifest"),
                IStreamArtistAttribution(address(artist))
            )
        )
        .code;
    }

    function testConfigMalformedAndNoncanonicalCalldataMatchesOriginal() public {
        for (uint8 kind; kind < 4; ++kind) {
            _corpus(_config(kind));
        }
    }

    function testLegacyAndScopedMalformedCalldataMatchesOriginal() public {
        for (uint8 kind; kind < 4; ++kind) {
            _corpus(_root(kind));
        }
    }

    function testPairedInvalidCollectionTokenAndArtistPreserveFirstError() public {
        bytes memory input = _config(1);
        _setWord(input, 0, 999);
        _sameFailure(input);
        input = _config(2);
        _setWord(input, 0, 999);
        _sameFailure(input);
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        for (uint8 kind; kind < 4; ++kind) {
            _corpus(_root(kind));
            _corpus(_config(kind));
        }
    }

    function testFuzzConfigWordMutationKeepsExactRefusal(uint8 kind, uint8 word, uint256 value)
        public
    {
        bytes memory input = _config(kind % 4);
        uint256 index = uint256(word) % ((input.length - 4) / 32);
        _setWord(input, index, value);
        _sameFailure(input);
    }

    function testFuzzRootWordMutationKeepsExactRefusal(uint8 kind, uint8 word, uint256 value)
        public
    {
        bytes memory input = _root(kind % 4);
        uint256 index = uint256(word) % ((input.length - 4) / 32);
        _setWord(input, index, value);
        _sameFailure(input);
    }

    function testCompleteCollectionReturnBytesAndUnknownGuardsMatchOriginal() public {
        _collectionReads(0);
        _collectionReads(1);
        _collectionReads(2);
        _collectionReads(999);
    }

    function testCollectionReadsKeepFullUtf8AndMaximumStoredFields() public {
        // No mint/consent transition is hidden by the codec: use the unminted second collection.
        core.setMinted(0);
        string memory longText = _text(2048);
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata,
                (
                    2,
                    unicode"艺术 \"title\"",
                    longText,
                    string.concat("ipfs://", _text(2041)),
                    string.concat("https://", _text(2040))
                )
            )
        );
        _admin(abi.encodeCall(router.setCollectionScript, (2, _text(8192))));
        _collectionReads(2);
        Facts.ServingSource memory expected = Facts.ServingSource(
            unicode"艺术 \"title\"",
            longText,
            string.concat("ipfs://", _text(2041)),
            string.concat("https://", _text(2040)),
            _text(8192)
        );
        (bool ok, bytes memory actual) =
            address(router).staticcall(abi.encodeCall(Facts.collectionServingSource, (2)));
        require(ok && keccak256(actual) == keccak256(abi.encode(expected)), "independent raw tuple");
    }

    function testUnknownLegacyRecordPreservesExactError() public {
        bytes memory input = abi.encodeCall(Root.contentRootRecord, (bytes32(uint256(123))));
        _sameFailure(input);
        (bool ok, bytes memory result) = address(router).staticcall(input);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            Root.ContentRootRecordUnknown.selector, bytes32(uint256(123))
                        )
                    ),
            "original unknown-record payload"
        );
    }

    function _collectionReads(uint256 id) private {
        _sameRead(abi.encodeCall(StreamMetadataRouter.collectionMetadata, (id)));
        _sameRead(abi.encodeCall(Facts.artistPresentation, (id)));
        _sameRead(abi.encodeCall(Facts.collectionServingFacts, (id)));
        _sameRead(abi.encodeCall(Facts.collectionServingSource, (id)));
        _sameRead(abi.encodeCall(Facts.collectionLiveArtistStatus, (id)));
        _sameRead(abi.encodeCall(StreamMetadataRouter.collectionScriptBundle, (id)));
    }

    function _config(uint8 kind) private pure returns (bytes memory) {
        // Invalid registry is intentional: every well-decoded mutation still reaches a refusal.
        S.ConfigInput memory value;
        value.config.mode = R.MetadataMode.ONCHAIN;
        if (kind == 0) return abi.encodeCall(S.setDefaultMetadataConfig, (value));
        if (kind == 1) return abi.encodeCall(S.setCollectionMetadataConfig, (1, value));
        if (kind == 2) return abi.encodeCall(S.setTokenMetadataConfig, (91, value));
        return abi.encodeCall(S.previewStaticMetadataConfig, (1, 91, value));
    }

    function _root(uint8 kind) private view returns (bytes memory) {
        if (kind < 2) {
            Root.Publication memory value = Root.Publication(1, 0, 0, "ipfs://codec");
            return kind == 0
                ? abi.encodeCall(Root.previewContentRootPublication, (value, address(this)))
                : abi.encodeCall(Root.publishVerifiedTokenContentRoot, (value));
        }
        Scoped.Publication memory scoped = Scoped.Publication(
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
            0,
            0,
            0,
            "ipfs://codec"
        );
        return kind == 2
            ? abi.encodeCall(Scoped.previewScopedContentRootPublication, (scoped, address(this)))
            : abi.encodeCall(Scoped.publishScopedContentRootPublication, (scoped));
    }

    function _corpus(bytes memory input) private {
        _sameFailure(input);
        _sameFailure(bytes.concat(input, hex"ff001122"));
        _sameFailure(_prefix(input, 4));
        _sameFailure(_prefix(input, 35));
        _sameFailure(_prefix(input, input.length - 1));
        for (uint256 i; i < (input.length - 4) / 32; ++i) {
            bytes memory changed = bytes.concat(input);
            _setWord(changed, i, type(uint256).max);
            _sameFailure(changed);
            _setWord(changed, i, 2);
            _sameFailure(changed);
        }
    }

    function _sameFailure(bytes memory input) private {
        uint256 snapshot = vm.snapshotState();
        (bool ok, bytes memory actual) = address(router).call(input);
        require(vm.revertToState(snapshot), "restore current");
        snapshot = vm.snapshotState();
        vm.etch(address(router), referenceCode);
        (bool oldOk, bytes memory expected) = address(router).call(input);
        require(vm.revertToState(snapshot), "restore reference");
        require(!ok && !oldOk, "failure corpus must refuse on both paths");
        require(keccak256(actual) == keccak256(expected), "exact old decoder/guard error");
    }

    function _sameRead(bytes memory input) private {
        (bool ok, bytes memory actual) = address(router).staticcall(input);
        uint256 snapshot = vm.snapshotState();
        vm.etch(address(router), referenceCode);
        (bool oldOk, bytes memory expected) = address(router).staticcall(input);
        require(vm.revertToState(snapshot), "restore reference read");
        require(ok == oldOk && keccak256(actual) == keccak256(expected), "complete old ABI return");
    }

    function _setWord(bytes memory input, uint256 index, uint256 value) private pure {
        assembly ("memory-safe") { mstore(add(add(input, 36), mul(index, 32)), value) }
    }

    function _prefix(bytes memory input, uint256 size) private pure returns (bytes memory result) {
        result = new bytes(size);
        for (uint256 i; i < size; ++i) {
            result[i] = input[i];
        }
    }

    function _text(uint256 size) private pure returns (string memory) {
        bytes memory result = new bytes(size);
        for (uint256 i; i < size; ++i) {
            result[i] = bytes1(uint8(97 + i % 26));
        }
        return string(result);
    }
}
