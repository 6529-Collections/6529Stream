// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistIdentityCreationPart
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityCreationPart.sol";
import {
    StreamArtistEstateCreationPart
} from "../../../smart-contracts/domains/artist/StreamArtistEstateCreationPart.sol";

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamArtistExtensionFactory
} from "../../../smart-contracts/domains/artist/StreamArtistExtensionFactory.sol";
import {
    StreamArtistCreationParts
} from "../../../smart-contracts/domains/artist/StreamArtistCreationParts.sol";
import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

interface ArtistCreationVm {
    function getCode(string calldata artifact) external view returns (bytes memory);
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
}

/// @notice Actual linked Factory, fragments and children; VM code corruption is an explicit refusal control.
/// @dev Artifact bytes are the independent compiler-output oracle. No substitute child or authority contract.
contract StreamArtistCreationCarriersTest is CharacterizationTestBase {
    ArtistCreationVm private constant avm = ArtistCreationVm(address(vm));
    string private constant PREFIX = "smart-contracts/domains/artist/";
    address[4] private parts;
    StreamArtistExtensionFactory private factory;

    function setUp() public {
        for (uint8 i; i < 4; ++i) {
            string memory name =
                i < 2 ? "StreamArtistIdentityCreationPart" : "StreamArtistEstateCreationPart";
            parts[i] = _create(name, abi.encode(uint8(i % 2)));
        }
        factory = StreamArtistExtensionFactory(
            _create("StreamArtistExtensionFactory", abi.encode(parts))
        );
    }

    function _code(string memory name) private view returns (bytes memory) {
        return avm.getCode(string.concat(PREFIX, name, ".sol:", name));
    }

    function _create(string memory name, bytes memory arguments) private returns (address result) {
        bytes memory code = bytes.concat(_code(name), arguments);
        require(code.length <= 49_152, "actual initcode limit");
        assembly ("memory-safe") {
            result := create(0, add(code, 32), mload(code))
            if iszero(result) {
                let reason := mload(64)
                returndatacopy(reason, 0, returndatasize())
                revert(reason, returndatasize())
            }
        }
        require(result.code.length <= 24_576, "actual runtime limit");
    }

    function createFactory(address[4] calldata supplied) external returns (address) {
        return _create("StreamArtistExtensionFactory", abi.encode(supplied));
    }

    function createPart(bool estate, uint8 index) external returns (address) {
        return _create(
            estate ? "StreamArtistEstateCreationPart" : "StreamArtistIdentityCreationPart",
            abi.encode(index)
        );
    }

    function _pins() private pure returns (address[6] memory) {
        return [
            address(0x101),
            address(0x102),
            address(0x103),
            address(0x104),
            address(0x105),
            address(0x106)
        ];
    }

    function _childName(uint8 kind) private pure returns (string memory) {
        return
            kind == 1
                ? "StreamArtistIdentityWriterExtension"
                : "StreamArtistIdentityEstateExtension";
    }

    function testExactCompilerImagesAndSixConstructorWords() public view {
        address[6] memory p = _pins();
        bytes memory args = abi.encode(p[0], p[1], p[2], p[3], p[4], p[5]);
        require(args.length == 192, "original constructor tuple");
        for (uint8 kind = 1; kind <= 2; ++kind) {
            bytes memory original = _code(_childName(kind));
            bytes memory actual = factory.extensionCreationCode(kind);
            require(
                keccak256(actual) == keccak256(original) && actual.length == original.length,
                "exact original image"
            );
            require(
                keccak256(bytes.concat(actual, args)) == keccak256(bytes.concat(original, args)),
                "full original initcode"
            );
            StreamArtistExtensionFactory.CreationImage memory image = factory.creationImage(kind);
            uint256 offset = (kind - 1) * 2;
            require(
                image.parts[0] == parts[offset] && image.parts[1] == parts[offset + 1],
                "ordered parts"
            );
            require(
                image.length == original.length && image.imageHash == keccak256(original),
                "canonical hash and length"
            );
            require(
                image.runtimeHashes[0] == parts[offset].codehash
                    && image.runtimeHashes[1] == parts[offset + 1].codehash,
                "exact runtime pins"
            );
            require(
                parts[offset].code.length == 16_385
                    && parts[offset + 1].code.length == original.length - 16_384 + 1,
                "actual returned sizes"
            );
            require(parts[offset].code[0] == 0 && parts[offset + 1].code[0] == 0, "STOP prefixes");
        }
        require(
            address(factory).codehash == keccak256(type(StreamArtistExtensionFactory).runtimeCode),
            "unchanged canonical runtime admission model"
        );
        require(avm.getNonce(address(factory)) == 1, "no constructor CREATE");
    }

    function testOriginalFactoryCreateIssuerNonceImmutablePinsAndBirthEvents() public {
        address[6] memory p = _pins();
        for (uint8 kind = 1; kind <= 2; ++kind) {
            address predicted = avm.computeCreateAddress(address(factory), kind);
            vm.recordLogs();
            address child = factory.deployIdentity(kind, p);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            require(
                child == predicted && avm.getNonce(address(factory)) == kind + 1,
                "one original Factory CREATE"
            );
            StreamArtistOwner owner = StreamArtistOwner(child);
            require(
                owner.artistRegistry() == p[1] && owner.operationCoordinator() == p[2]
                    && owner.archiveV2() == p[3],
                "original identity pins"
            );
            require(
                owner.core() == p[4] && owner.mintManager() == p[5]
                    && owner.deploymentChainId() == block.chainid,
                "original environment"
            );
            bytes32 binding = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_EXTENSION_BIRTH_V1"), block.chainid, kind, p
                )
            );
            StreamArtistExtensionFactory.Birth memory b = factory.birth(child);
            require(
                b.kind == kind && b.host == p[0] && b.chainId == block.chainid
                    && b.bindingHash == binding && b.runtimeCodeHash == child.codehash,
                "original birth"
            );
            uint256 found;
            for (uint256 i; i < logs.length; ++i) {
                if (logs[i].emitter != address(factory)) continue;
                ++found;
                require(
                    logs[i].topics.length == 4
                        && logs[i].topics[0]
                            == keccak256("ExtensionCreated(address,address,uint8,bytes32,bytes32)"),
                    "original event"
                );
                require(
                    logs[i].topics[1] == bytes32(uint256(uint160(child)))
                        && logs[i].topics[2] == bytes32(uint256(uint160(p[0])))
                        && logs[i].topics[3] == bytes32(uint256(kind)),
                    "original indexed fields"
                );
                require(
                    keccak256(logs[i].data) == keccak256(abi.encode(binding, child.codehash)),
                    "original event bytes"
                );
            }
            require(found == 1, "one original birth event");
            address direct =
                _create(_childName(kind), abi.encode(p[0], p[1], p[2], p[3], p[4], p[5]));
            require(
                direct.codehash == child.codehash,
                "same constructor-bound runtime as original CREATE"
            );
        }
    }

    function testOriginalConstructorFailureBubblesAndRollsBackCreateNonce() public {
        address[6] memory p = _pins();
        p[1] = address(0);
        for (uint8 kind = 1; kind <= 2; ++kind) {
            uint64 nonce = avm.getNonce(address(factory));
            address predicted = avm.computeCreateAddress(address(factory), nonce);
            vm.expectRevert(abi.encodeWithSelector(T.InvalidBinding.selector));
            factory.deployIdentity(kind, p);
            require(
                avm.getNonce(address(factory)) == nonce && predicted.code.length == 0
                    && factory.birth(predicted).kind == 0,
                "original failure rollback"
            );
        }
    }

    function testConstructorRejectsMissingSwappedForeignAndDuplicateParts() public {
        address[4] memory supplied = parts;
        supplied[0] = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionFactory.InvalidCreationImage.selector, uint8(1)
            )
        );
        this.createFactory(supplied);
        supplied = parts;
        supplied[0] = parts[1];
        supplied[1] = parts[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionFactory.InvalidCreationImage.selector, uint8(1)
            )
        );
        this.createFactory(supplied);
        supplied = parts;
        supplied[0] = parts[2];
        supplied[1] = parts[3];
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionFactory.InvalidCreationImage.selector, uint8(1)
            )
        );
        this.createFactory(supplied);
        supplied = parts;
        supplied[1] = parts[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionFactory.InvalidCreationImage.selector, uint8(1)
            )
        );
        this.createFactory(supplied);
    }

    function testConstructorRejectsSameLengthTamperingThenExactInputRetry() public {
        bytes memory saved = parts[3].code;
        bytes memory corrupt = abi.decode(abi.encode(saved), (bytes));
        corrupt[corrupt.length - 1] = bytes1(uint8(corrupt[corrupt.length - 1]) ^ 1);
        vm.etch(parts[3], corrupt);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionFactory.InvalidCreationImage.selector, uint8(2)
            )
        );
        this.createFactory(parts);
        vm.etch(parts[3], saved);
        address result = this.createFactory(parts);
        require(
            result.codehash == address(factory).codehash && avm.getNonce(result) == 1,
            "same exact inputs accepted after restoration"
        );
    }

    function testPinnedPartDriftFailsBeforeCreateAndIdenticalCallRetries() public {
        address[6] memory p = _pins();
        bytes memory originalCall = abi.encodeCall(factory.deployIdentity, (uint8(1), p));
        bytes memory saved = parts[0].code;
        bytes memory corrupt = abi.decode(abi.encode(saved), (bytes));
        corrupt[16_384] = bytes1(uint8(corrupt[16_384]) ^ 1);
        vm.etch(parts[0], corrupt);
        uint64 nonce = avm.getNonce(address(factory));
        address predicted = avm.computeCreateAddress(address(factory), nonce);
        (bool ok, bytes memory reason) = address(factory).call(originalCall);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamArtistExtensionFactory.InvalidCreationImage.selector, uint8(1)
                        )
                    ),
            "exact fail-closed drift"
        );
        require(
            avm.getNonce(address(factory)) == nonce && predicted.code.length == 0
                && factory.birth(predicted).kind == 0,
            "no create or birth on drift"
        );
        vm.etch(parts[0], saved);
        (ok, reason) = address(factory).call(originalCall);
        require(
            ok && abi.decode(reason, (address)) == predicted && factory.birth(predicted).kind == 1,
            "identical call retry"
        );
    }

    function testNonStopPrefixAndUnsupportedPartIndexRefuse() public {
        bytes memory saved = parts[0].code;
        bytes memory corrupt = abi.decode(abi.encode(saved), (bytes));
        corrupt[0] = 0x01;
        vm.etch(parts[0], corrupt);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionFactory.InvalidCreationImage.selector, uint8(1)
            )
        );
        this.createFactory(parts);
        vm.etch(parts[0], saved);
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistCreationParts.InvalidCreationPart.selector)
        );
        this.createPart(false, 2);
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistCreationParts.InvalidCreationPart.selector)
        );
        this.createPart(true, 2);
    }

    function testUnknownImageDoesNotIntroduceAnotherCreationRoute() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionFactory.InvalidCreationImage.selector, uint8(3)
            )
        );
        factory.extensionCreationCode(3);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionFactory.InvalidCreationImage.selector, uint8(0)
            )
        );
        factory.creationImage(0);
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistExtensionFactory.InvalidExtensionBirth.selector)
        );
        factory.deployIdentity(0, _pins());
        require(avm.getNonce(address(factory)) == 1, "invalid routes never create");
    }
}
