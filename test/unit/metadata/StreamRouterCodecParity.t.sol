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
    IStreamPolicyContentRootPublicationV2 as PolicyRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    IStreamMetadataServingFacts as Facts
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Canonical error/read parity and atomic raw-input refusal against the original methods.
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

    function testConfigMalformedAndNoncanonicalCalldataBothRefuseAtomically() public {
        for (uint8 kind; kind < 4; ++kind) {
            _corpus(_config(kind));
        }
    }

    function testLegacyAndScopedMalformedCalldataBothRefuseAtomically() public {
        for (uint8 kind; kind < 4; ++kind) {
            _corpus(_root(kind));
        }
    }

    function testPolicyRootMalformedCalldataBothRefuseAtomically() public {
        _corpus(_root(4));
        _corpus(_root(5));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        _sameFailure(_root(4));
        _sameFailure(_root(5));
    }

    function testFuzzCanonicalPolicyRootFieldsKeepExactError(
        bool publish,
        uint256 collectionId,
        bytes32 previous,
        string calldata uri
    ) public {
        _sameFailure(_encodeRoot(publish ? 5 : 4, collectionId, previous, uri));
    }

    function testPairedInvalidCollectionTokenAndArtistPreserveFirstError() public {
        bytes memory input = _config(1);
        _setWord(input, 0, 999);
        _sameFailure(input);
        input = _config(2);
        _setWord(input, 0, 999);
        _sameFailure(input);
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        // Check all canonical guards before any malformed corpus can stop the test.
        for (uint8 kind; kind < 4; ++kind) {
            _sameFailure(_root(kind));
            _sameFailure(_config(kind));
        }
        for (uint8 kind; kind < 4; ++kind) {
            _corpus(_root(kind));
            _corpus(_config(kind));
        }
    }

    function testFuzzConfigWordMutationBothRefuseAtomically(uint8 kind, uint8 word, uint256 value)
        public
    {
        bytes memory input = _config(kind % 4);
        uint256 index = uint256(word) % ((input.length - 4) / 32);
        _setWord(input, index, value);
        _bothReject(input);
    }

    function testFuzzRootWordMutationBothRefuseAtomically(uint8 kind, uint8 word, uint256 value)
        public
    {
        bytes memory input = _root(kind % 4);
        uint256 index = uint256(word) % ((input.length - 4) / 32);
        _setWord(input, index, value);
        _bothReject(input);
    }

    function testFuzzCanonicalConfigFieldsKeepExactError(uint8 kind, uint8 field, uint256 value)
        public
    {
        S.ConfigInput memory input;
        input.config.mode = R.MetadataMode.ONCHAIN;
        uint256 collectionId = 1;
        uint256 tokenId = 91;
        field %= 10;
        if (field == 0) input.registry = address(uint160(value));
        else if (field == 1) input.versionKey = bytes32(value);
        else if (field == 2) input.config.mode = R.MetadataMode(value % 3);
        else if (field == 3) input.config.renderer = address(uint160(value));
        else if (field == 4) input.config.baseURI = _text(value % 65);
        else if (field == 5) input.config.pendingURI = _text(value % 65);
        else if (field == 6) input.config.offchainURIIdMode = R.OffchainURIIdMode(value % 2);
        else if (field == 7) input.config.frozen = value % 2 == 1;
        else if (field == 8) collectionId = value;
        else tokenId = value;
        // One field changes at a time: registry/version never become a valid admitted pair.
        _sameFailure(_encodeConfig(kind % 4, input, collectionId, tokenId));
    }

    function testFuzzCanonicalRootFieldsKeepExactError(
        uint8 kind,
        uint256 collectionId,
        bytes32 previous,
        string calldata uri
    ) public {
        _sameFailure(_encodeRoot(kind % 4, collectionId, previous, uri));
    }

    function testBackwardConfigOffsetBothRefuseAtomically() public {
        bytes memory input = _config(0);
        // Original signed calldata bounds can observe backward offsets. A wrapper must still
        // refuse this input without effects, even when its decoder uses a different error.
        _setWord(input, 3, type(uint256).max - 235);
        _bothReject(input);
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
        return _encodeConfig(kind, value, 1, 91);
    }

    function _encodeConfig(
        uint8 kind,
        S.ConfigInput memory value,
        uint256 collectionId,
        uint256 tokenId
    ) private pure returns (bytes memory) {
        if (kind == 0) {
            return abi.encodeCall(S.setDefaultMetadataConfig, (value));
        }
        if (kind == 1) return abi.encodeCall(S.setCollectionMetadataConfig, (collectionId, value));
        if (kind == 2) return abi.encodeCall(S.setTokenMetadataConfig, (tokenId, value));
        return abi.encodeCall(S.previewStaticMetadataConfig, (collectionId, tokenId, value));
    }

    function _root(uint8 kind) private view returns (bytes memory) {
        return _encodeRoot(kind, 1, 0, "ipfs://codec");
    }

    function _encodeRoot(uint8 kind, uint256 collectionId, bytes32 previous, string memory uri)
        private
        view
        returns (bytes memory)
    {
        if (kind >= 4) {
            Root.Publication memory value = Root.Publication(collectionId, previous, 0, uri);
            return kind == 4
                ? abi.encodeCall(
                    PolicyRoot.previewPolicyContentRootPublication, (value, address(this))
                )
                : abi.encodeCall(PolicyRoot.publishVerifiedPolicyContentRoot, (value));
        }
        if (kind < 2) {
            Root.Publication memory value = Root.Publication(collectionId, previous, 0, uri);
            return kind == 0
                ? abi.encodeCall(Root.previewContentRootPublication, (value, address(this)))
                : abi.encodeCall(Root.publishVerifiedTokenContentRoot, (value));
        }
        Scoped.Publication memory scoped = Scoped.Publication(
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0),
            previous,
            0,
            0,
            uri
        );
        return kind == 2
            ? abi.encodeCall(Scoped.previewScopedContentRootPublication, (scoped, address(this)))
            : abi.encodeCall(Scoped.publishScopedContentRootPublication, (scoped));
    }

    function _corpus(bytes memory input) private {
        _sameFailure(input);
        _sameFailure(bytes.concat(input, hex"ff001122"));
        _bothReject(_prefix(input, 4));
        _bothReject(_prefix(input, 35));
        _bothReject(_prefix(input, input.length - 1));
        for (uint256 i; i < (input.length - 4) / 32; ++i) {
            bytes memory changed = bytes.concat(input);
            _setWord(changed, i, type(uint256).max);
            _bothReject(changed);
            _setWord(changed, i, 2);
            _bothReject(changed);
        }
    }

    function _sameFailure(bytes memory input) private {
        (bytes memory actual, bytes memory expected) = _refusals(input);
        require(keccak256(actual) == keccak256(expected), "exact canonical guard error");
    }

    function _bothReject(bytes memory input) private {
        _refusals(input);
    }

    function _refusals(bytes memory input)
        private
        returns (bytes memory actual, bytes memory expected)
    {
        uint256 snapshot = vm.snapshotState();
        bytes32 beforeState = _stateDigest();
        bool ok;
        (ok, actual) = address(router).call(input);
        // Assert before restoring the snapshot: isolation must not conceal persistent effects.
        require(_stateDigest() == beforeState, "refusal preserves config/root/collection state");
        require(vm.revertToState(snapshot), "restore current");
        snapshot = vm.snapshotState();
        vm.etch(address(router), referenceCode);
        bool oldOk;
        (oldOk, expected) = address(router).call(input);
        require(vm.revertToState(snapshot), "restore reference");
        require(!ok && !oldOk, "failure corpus must refuse on both paths");
    }

    function _stateDigest() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                router.defaultMetadataConfig(),
                router.collectionMetadataConfig(1),
                router.resolvedMetadataConfig(91),
                router.collectionContentRootHead(1),
                router.scopedContentRootAggregate(1),
                router.collectionMetadata(1)
            )
        );
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
