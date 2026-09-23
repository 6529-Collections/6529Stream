// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRecordArtistIdentityReads as Reads
} from "../../../smart-contracts/domains/records/StreamRecordArtistIdentityReads.sol";
import {
    IStreamCollectionMetadataV1 as M
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

interface CurrentRecordIdentityVm {
    function expectRevert() external;
    function expectRevert(bytes calldata reason) external;
    function etch(address target, bytes calldata code) external;
    function chainId(uint256 chain) external;
}

/// @dev Exact typed ABI-response boundary for Core, Metadata, Router, registry, Coordinator
/// and owners. Each read is keyed by complete calldata, including pointer kind/artist ID.
/// No selected()/Configuration result is mocked: the production libraries perform those joins.
contract CurrentRecordIdentityResponseBoundary {
    mapping(bytes32 => bytes) private responses;

    function answer(bytes memory input, bytes memory output) external {
        responses[keccak256(input)] = output;
    }

    fallback() external {
        bytes memory output = responses[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

/// @dev Same response storage layout, deliberately different runtime for code-drift negatives.
contract CurrentRecordIdentityReplacement is CurrentRecordIdentityResponseBoundary {
    function differentRuntime() external pure returns (uint256) {
        return 1;
    }
}

/// @notice Actual current-selection/Configuration/record-identity read libraries with named
/// response boundaries. This suite does not execute actual Core cutover or Artist operations 55–60.
/// Constructor commitments and completed-owner claims below are independent typed fixture inputs.
contract StreamRecordArtistCurrentIdentityReadsTest {
    CurrentRecordIdentityVm private constant vm =
        CurrentRecordIdentityVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant CAP = 200000;
    bytes32 private constant ARTIST = bytes32(uint256(33));
    bytes32 private constant REGISTRATION = bytes32(uint256(77));
    bytes32 private constant COMPLETION = keccak256("complete seven-owner fixture claim");
    bytes32 private constant ARTIST_POINTER = keccak256("ARTIST_REGISTRY");
    bytes32 private constant ROUTER_POINTER = keccak256("METADATA_ROUTER");
    bytes4 private constant SUITE = bytes4(keccak256("suiteConfiguration()"));
    bytes4 private constant STATE = bytes4(keccak256("authorityState(bytes32)"));
    bytes4 private constant COMPLETE = bytes4(keccak256("authorityHydrationCommitment()"));
    CurrentRecordIdentityResponseBoundary private metadata;
    CurrentRecordIdentityResponseBoundary private core;
    CurrentRecordIdentityResponseBoundary private router;
    CurrentRecordIdentityResponseBoundary[2] private registries;
    CurrentRecordIdentityResponseBoundary[2] private coordinators;
    CurrentRecordIdentityResponseBoundary[2] private archives;
    CurrentRecordIdentityResponseBoundary[7][2] private owners;
    CurrentRecordIdentityResponseBoundary[5] private dependencies;
    CurrentRecordIdentityResponseBoundary private finality;
    CurrentRecordIdentityResponseBoundary private provider;
    uint256 private originalChain;

    function setUp() public {
        originalChain = block.chainid;
        metadata = new CurrentRecordIdentityResponseBoundary();
        core = new CurrentRecordIdentityResponseBoundary();
        router = new CurrentRecordIdentityResponseBoundary();
        finality = new CurrentRecordIdentityResponseBoundary();
        provider = new CurrentRecordIdentityResponseBoundary();
        for (uint256 i; i < dependencies.length; ++i) {
            dependencies[i] = new CurrentRecordIdentityResponseBoundary();
        }
        for (uint256 side; side < 2; ++side) {
            registries[side] = new CurrentRecordIdentityResponseBoundary();
            coordinators[side] = new CurrentRecordIdentityResponseBoundary();
            archives[side] = new CurrentRecordIdentityResponseBoundary();
            for (uint256 i; i < 7; ++i) {
                owners[side][i] = new CurrentRecordIdentityResponseBoundary();
                _answer(owners[side][i], "core()", abi.encode(address(core)));
                _answer(owners[side][i], "artistRegistry()", abi.encode(address(registries[side])));
                _answer(
                    owners[side][i],
                    "operationCoordinator()",
                    abi.encode(address(coordinators[side]))
                );
                _answer(owners[side][i], "deploymentChainId()", abi.encode(originalChain));
                _answer(owners[side][i], "archiveV2()", abi.encode(address(archives[side])));
                _answer(owners[side][i], "mintManager()", abi.encode(address(dependencies[0])));
                _answer(owners[side][i], "domainId()", abi.encode(keccak256(abi.encode(i))));
                owners[side][i].answer(abi.encodeWithSelector(COMPLETE), abi.encode(COMPLETION));
            }
            _answer(registries[side], "core()", abi.encode(address(core)));
            _answer(
                registries[side], "operationCoordinator()", abi.encode(address(coordinators[side]))
            );
            _answer(coordinators[side], "deploymentChainId()", abi.encode(originalChain));
            _answer(coordinators[side], "finalityRegistry()", abi.encode(address(finality)));
            _answer(coordinators[side], "finalityEvidenceProvider()", abi.encode(address(provider)));
            _installSuite(side, _suite(side));
            _authority(side, abi.encode(address(0xA), uint256(1), uint256(1), REGISTRATION));
        }
        _answer(metadata, "core()", abi.encode(address(core)));
        _answer(metadata, "coreCodeHash()", abi.encode(address(core).codehash));
        _answer(metadata, "artistRegistry()", abi.encode(address(registries[0])));
        _answer(metadata, "artistRegistryCodeHash()", abi.encode(address(registries[0]).codehash));
        _answer(router, "core()", abi.encode(address(core)));
        _lineage();
        _pointer(ARTIST_POINTER, address(registries[0]));
        _pointer(ROUTER_POINTER, address(router));
    }

    function _answer(
        CurrentRecordIdentityResponseBoundary target,
        string memory signature,
        bytes memory value
    ) private {
        target.answer(abi.encodeWithSignature(signature), value);
    }

    function _pointerInput(bytes32 kind) private pure returns (bytes memory) {
        return abi.encodeWithSignature("getSatellitePointer(bytes32)", kind);
    }

    function _pointerBytes(bytes32 kind, address target) private view returns (bytes memory) {
        return abi.encode(
            target,
            target.codehash,
            false,
            kind,
            bytes4(0x12345678),
            address(dependencies[1]),
            uint8(1),
            keccak256("manifest"),
            keccak256("deployment"),
            uint64(1)
        );
    }

    function _pointer(bytes32 kind, address target) private {
        core.answer(_pointerInput(kind), _pointerBytes(kind, target));
    }

    function _lineage() private {
        _answer(
            registries[0],
            "artistRegistryCutover()",
            abi.encode(true, address(registries[1]), uint64(10))
        );
        _answer(registries[1], "importedHistoryBindingCount()", abi.encode(uint256(1)));
        registries[1].answer(
            abi.encodeWithSignature("importedHistoryBinding(uint256)", uint256(0)),
            abi.encode(address(registries[0]), uint64(9), keccak256("root"), keccak256("manifest"))
        );
        registries[1].answer(
            abi.encodeWithSignature(
                "artistHistoryPredecessorBinding(address)", address(registries[0])
            ),
            abi.encode(true, address(registries[0]).codehash, uint256(1))
        );
    }

    function _suite(uint256 side) private view returns (uint256[17] memory words) {
        // Literal permanent 17-word order; no production SuiteConfiguration encoder/preview.
        words[0] = uint160(address(registries[side]));
        words[1] = uint160(address(archives[side]));
        for (uint256 i; i < 7; ++i) {
            words[2 + i] = uint160(address(owners[side][i]));
        }
        words[9] = uint160(address(core));
        words[10] = uint160(address(dependencies[0]));
        words[11] = uint160(address(dependencies[1]));
        words[12] = uint160(address(router));
        words[13] = uint160(address(dependencies[2]));
        words[14] = uint160(address(dependencies[3]));
        words[15] = type(uint256).max; // The revenue class is a full-width hash, not an address.
        words[16] = uint160(address(dependencies[4]));
    }

    function _configuration(uint256 side, uint256[17] memory words) private view returns (bytes32) {
        bytes32[16] memory hashes;
        for (uint256 i; i < 7; ++i) {
            hashes[i] = address(uint160(words[2 + i])).codehash;
        }
        hashes[7] = address(uint160(words[0])).codehash;
        hashes[8] = address(uint160(words[1])).codehash;
        for (uint256 i = 9; i < 15; ++i) {
            hashes[i] = address(uint160(words[i])).codehash;
        }
        hashes[15] = address(uint160(words[16])).codehash;
        uint16[40] memory operations = [
            uint16(1),
            2,
            3,
            4,
            5,
            6,
            7,
            12,
            13,
            14,
            15,
            16,
            17,
            18,
            20,
            21,
            22,
            23,
            24,
            25,
            26,
            27,
            28,
            29,
            30,
            31,
            32,
            33,
            34,
            35,
            36,
            37,
            38,
            39,
            40,
            51,
            52,
            54,
            58,
            65534
        ];
        bytes32[10] memory profiles = [
            keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_PROFILE_V1"),
            keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_PROFILE_V1"),
            keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_PROFILE_V1"),
            keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_PROFILE_V1"),
            keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_PROFILE_V1"),
            keccak256("6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_PROFILE_V1"),
            keccak256("6529STREAM_ARTIST_GUARDIAN_HEAD_SELECTION_PROFILE_V1"),
            keccak256("6529STREAM_ARTIST_GUARDIAN_ROOT_APPEAL_PROFILE_V1"),
            keccak256("6529STREAM_ARTIST_FIRST_ESTATE_RECOVERY_PROFILE_V1"),
            keccak256("6529STREAM_ARTIST_ESTATE_SUCCESSOR_GUARDIAN_RECOVERY_PROFILE_V1")
        ];
        // Fixed arrays encode as the same consecutive 32-byte words as the permanent preimage.
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                    originalChain,
                    address(coordinators[side]),
                    words,
                    hashes,
                    address(finality),
                    address(finality).codehash,
                    address(provider),
                    address(provider).codehash
                ),
                abi.encode(operations),
                abi.encode(profiles)
            )
        );
    }

    function _installSuite(uint256 side, uint256[17] memory words) private {
        coordinators[side].answer(abi.encodeWithSelector(SUITE), abi.encode(words));
        _answer(coordinators[side], "configurationHash()", abi.encode(_configuration(side, words)));
    }

    function _authority(uint256 side, bytes memory value) private {
        owners[side][2].answer(abi.encodeWithSelector(STATE, ARTIST), value);
    }

    function _current() private view returns (Reads.Pins memory) {
        return Reads.resolveCurrent(address(metadata), address(core), originalChain, CAP);
    }

    function _known(Reads.Pins memory pins) private view returns (bytes32) {
        return Reads.knownCurrentIdentity(
            address(metadata), address(core), originalChain, pins, ARTIST, CAP
        );
    }

    function _historical() private view returns (Reads.Pins memory) {
        return Reads.resolve(address(metadata), address(core), originalChain, CAP);
    }

    function _assertCurrent(uint256 side) private view {
        Reads.Pins memory pins = _current();
        address[3] memory expected =
            [address(registries[side]), address(coordinators[side]), address(owners[side][2])];
        for (uint256 i; i < 3; ++i) {
            require(
                pins.targets[i] == expected[i] && pins.codeHashes[i] == expected[i].codehash,
                "exact current pins"
            );
        }
        require(_known(pins) == REGISTRATION, "immutable original registration");
    }

    function testOriginalCurrentMatchesUnchangedHistoricalIdentity() public view {
        require(
            keccak256(abi.encode(_current())) == keccak256(abi.encode(_historical())),
            "original equivalence"
        );
        _assertCurrent(0);
    }

    function testCompleteDirectSuccessorUsesActualSelectedOwnersTwo() public {
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        require(
            _historical().targets[0] == address(registries[0]), "original metadata anchor retained"
        );
    }

    function testSelectionRecheckedBetweenResolveAndKnownRejectsSavedOldPins() public {
        _assertCurrent(0);
        Reads.Pins memory original = _current();
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.ArtistIdentityDependencyChanged.selector, address(registries[1])
            )
        );
        _known(original);
        Reads.Pins memory successor = _current();
        require(_known(successor) == REGISTRATION, "fresh selected pins");
        _pointer(ARTIST_POINTER, address(registries[0]));
        _assertCurrent(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.ArtistIdentityDependencyChanged.selector, address(registries[0])
            )
        );
        _known(successor);
        require(_known(original) == REGISTRATION, "same original pins when actually selected again");
    }

    function testEveryOwnerRequiresExactNonzeroFullWordCompletionThenSameInputRepairs() public {
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        for (uint256 i; i < 7; ++i) {
            bytes[4] memory bad = [
                abi.encode(bytes32(0)),
                abi.encode(COMPLETION ^ bytes32(uint256(1))),
                new bytes(31),
                bytes.concat(abi.encode(COMPLETION), bytes32(0))
            ];
            for (uint256 j; j < bad.length; ++j) {
                owners[1][i].answer(abi.encodeWithSelector(COMPLETE), bad[j]);
                vm.expectRevert(
                    j < 2
                        ? abi.encodeWithSelector(M.MetadataHostNotSelected.selector)
                        : abi.encodeWithSelector(
                            M.MetadataReadFailed.selector, address(owners[1][i])
                        )
                );
                _current();
                owners[1][i].answer(abi.encodeWithSelector(COMPLETE), abi.encode(COMPLETION));
                _assertCurrent(1);
            }
        }
    }

    function testSealPredecessorHashCountSnapshotRootAndManifestAreAllRequired() public {
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        bytes[3] memory seals = [
            abi.encode(false, address(registries[1]), uint64(10)),
            abi.encode(true, address(0), uint64(10)),
            abi.encode(true, address(registries[1]), uint64(0))
        ];
        for (uint256 i; i < seals.length; ++i) {
            _answer(registries[0], "artistRegistryCutover()", seals[i]);
            vm.expectRevert(abi.encodeWithSelector(M.MetadataHostNotSelected.selector));
            _current();
            _lineage();
            _assertCurrent(1);
        }
        for (uint256 i; i < 2; ++i) {
            _answer(
                registries[1],
                "importedHistoryBindingCount()",
                abi.encode(i == 0 ? uint256(0) : uint256(2))
            );
            vm.expectRevert(abi.encodeWithSelector(M.MetadataHostNotSelected.selector));
            _current();
            _lineage();
            _assertCurrent(1);
        }
        for (uint256 i; i < 5; ++i) {
            registries[1].answer(
                abi.encodeWithSignature("importedHistoryBinding(uint256)", uint256(0)),
                abi.encode(
                    i == 0 ? address(router) : address(registries[0]),
                    i == 1 ? uint64(0) : i == 2 ? uint64(11) : uint64(9),
                    i == 3 ? bytes32(0) : keccak256("root"),
                    i == 4 ? bytes32(0) : keccak256("manifest")
                )
            );
            vm.expectRevert(abi.encodeWithSelector(M.MetadataHostNotSelected.selector));
            _current();
            _lineage();
            _assertCurrent(1);
        }
        for (uint256 i; i < 3; ++i) {
            registries[1].answer(
                abi.encodeWithSignature(
                    "artistHistoryPredecessorBinding(address)", address(registries[0])
                ),
                abi.encode(
                    i != 0,
                    i == 1 ? bytes32(0) : address(registries[0]).codehash,
                    i == 2 ? uint256(2) : uint256(1)
                )
            );
            vm.expectRevert(abi.encodeWithSelector(M.MetadataHostNotSelected.selector));
            _current();
            _lineage();
            _assertCurrent(1);
        }
    }

    function testRouterAndSuiteMustRetainTheActualCoreRelationship() public {
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        _pointer(ROUTER_POINTER, address(dependencies[0]));
        vm.expectRevert(abi.encodeWithSelector(M.MetadataHostNotSelected.selector));
        _current();
        _pointer(ROUTER_POINTER, address(router));
        _assertCurrent(1);
        _answer(router, "core()", abi.encode(address(dependencies[0])));
        vm.expectRevert(abi.encodeWithSelector(M.MetadataHostNotSelected.selector));
        _current();
        _answer(router, "core()", abi.encode(address(core)));
        _assertCurrent(1);
        uint256[17] memory words = _suite(1);
        words[9] = uint160(address(dependencies[0]));
        // A coherent hash cannot authorize a suite for a different Core.
        _installSuite(1, words);
        vm.expectRevert(abi.encodeWithSelector(M.MetadataHostNotSelected.selector));
        _current();
        _installSuite(1, _suite(1));
        _assertCurrent(1);
    }

    function testLiveRuntimeAndExpectedRuntimePinsCannotBeSubstituted() public {
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        Reads.Pins memory pins = _current();
        CurrentRecordIdentityReplacement replacement = new CurrentRecordIdentityReplacement();
        address[4] memory targets = [
            address(registries[0]),
            address(registries[1]),
            address(coordinators[1]),
            address(owners[1][2])
        ];
        for (uint256 i; i < targets.length; ++i) {
            bytes memory code = targets[i].code;
            vm.etch(targets[i], address(replacement).code);
            vm.expectRevert(
                i < 2
                    ? abi.encodeWithSelector(M.MetadataDependencyChanged.selector, targets[i])
                    : i == 2
                        ? abi.encodeWithSelector(
                            Reads.ArtistIdentityDependencyChanged.selector, targets[i]
                        )
                        : abi.encodeWithSelector(M.MetadataHostNotSelected.selector)
            );
            _known(pins);
            vm.etch(targets[i], code);
            require(_known(pins) == REGISTRATION, "same pins after runtime repair");
        }
        for (uint256 i; i < 3; ++i) {
            pins.codeHashes[i] ^= bytes32(uint256(1));
            vm.expectRevert(
                abi.encodeWithSelector(
                    Reads.ArtistIdentityDependencyChanged.selector, pins.targets[i]
                )
            );
            _known(pins);
            pins.codeHashes[i] ^= bytes32(uint256(1));
            require(_known(pins) == REGISTRATION, "restored saved runtime hash");
            address old = pins.targets[i];
            pins.targets[i] = address(router);
            vm.expectRevert(
                abi.encodeWithSelector(Reads.ArtistIdentityDependencyChanged.selector, old)
            );
            _known(pins);
            pins.targets[i] = old;
            require(_known(pins) == REGISTRATION, "restored saved address");
        }
        require(_known(pins) == REGISTRATION, "unmodified saved pins retry");
    }

    function testIdentityReciprocalBindingsCoordinatorAndOriginalChainRemainMandatory() public {
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        CurrentRecordIdentityResponseBoundary[6] memory targets = [
            registries[1], owners[1][2], owners[1][2], owners[1][2], owners[1][2], coordinators[1]
        ];
        string[6] memory signatures = [
            "core()",
            "core()",
            "artistRegistry()",
            "operationCoordinator()",
            "deploymentChainId()",
            "deploymentChainId()"
        ];
        bytes[6] memory good = [
            abi.encode(address(core)),
            abi.encode(address(core)),
            abi.encode(address(registries[1])),
            abi.encode(address(coordinators[1])),
            abi.encode(originalChain),
            abi.encode(originalChain)
        ];
        for (uint256 i; i < targets.length; ++i) {
            _answer(targets[i], signatures[i], abi.encode(uint256(0xBAD)));
            vm.expectRevert(abi.encodeWithSelector(Reads.InvalidArtistIdentityContext.selector));
            _current();
            _answer(targets[i], signatures[i], good[i]);
            _assertCurrent(1);
        }
        _answer(registries[0], "operationCoordinator()", abi.encode(address(coordinators[1])));
        vm.expectRevert(abi.encodeWithSelector(M.MetadataHostNotSelected.selector));
        _current();
        _answer(registries[0], "operationCoordinator()", abi.encode(address(coordinators[0])));
        _assertCurrent(1);
        vm.chainId(originalChain + 1);
        vm.expectRevert(abi.encodeWithSelector(Reads.InvalidArtistIdentityContext.selector));
        _current();
        vm.chainId(originalChain);
        _assertCurrent(1);
    }

    function testMalformedPointerSuiteAndConfigurationWordsRefuseExactRepair() public {
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        bytes memory originalPointer = _pointerBytes(ARTIST_POINTER, address(registries[1]));
        bytes[3] memory badPointers = [
            new bytes(319),
            bytes.concat(originalPointer, bytes32(0)),
            _pointerBytes(ARTIST_POINTER, address(registries[1]))
        ];
        _writeWord(badPointers[2], 0, bytes32(uint256(1) << 160));
        for (uint256 i; i < badPointers.length; ++i) {
            core.answer(_pointerInput(ARTIST_POINTER), badPointers[i]);
            vm.expectRevert();
            _current();
            core.answer(_pointerInput(ARTIST_POINTER), originalPointer);
            _assertCurrent(1);
        }
        for (uint256 i; i < 17; ++i) {
            if (i == 15) continue;
            uint256[17] memory words = _suite(1);
            words[i] = uint256(1) << 160;
            coordinators[1].answer(abi.encodeWithSelector(SUITE), abi.encode(words));
            vm.expectRevert();
            _current();
            _installSuite(1, _suite(1));
            _assertCurrent(1);
        }
        bytes[2] memory badSuites =
            [new bytes(543), bytes.concat(abi.encode(_suite(1)), bytes32(0))];
        for (uint256 i; i < badSuites.length; ++i) {
            coordinators[1].answer(abi.encodeWithSelector(SUITE), badSuites[i]);
            vm.expectRevert();
            _current();
            _installSuite(1, _suite(1));
            _assertCurrent(1);
        }
        bytes[3] memory badHashes = [
            new bytes(31),
            abi.encode(_configuration(1, _suite(1)), bytes32(0)),
            abi.encode(bytes32(uint256(1)))
        ];
        for (uint256 i; i < badHashes.length; ++i) {
            _answer(coordinators[1], "configurationHash()", badHashes[i]);
            vm.expectRevert(
                i < 2
                    ? abi.encodeWithSelector(
                        M.MetadataReadFailed.selector, address(coordinators[1])
                    )
                    : abi.encodeWithSelector(M.MetadataHostNotSelected.selector)
            );
            _current();
            _installSuite(1, _suite(1));
            _assertCurrent(1);
        }
    }

    function _writeWord(bytes memory value, uint256 index, bytes32 word) private pure {
        assembly ("memory-safe") { mstore(add(add(value, 32), mul(index, 32)), word) }
    }

    function testZeroUnknownAndNoncanonicalAuthorityRejectThenSameArtistRetries() public {
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        Reads.Pins memory pins = _current();
        vm.expectRevert(abi.encodeWithSelector(Reads.UnknownRecordArtist.selector, bytes32(0)));
        Reads.knownCurrentIdentity(address(metadata), address(core), originalChain, pins, 0, CAP);
        require(_known(pins) == REGISTRATION, "same selected graph with nonzero artist");
        _authority(1, abi.encode(address(0), uint256(0), uint256(0), bytes32(0)));
        vm.expectRevert(abi.encodeWithSelector(Reads.UnknownRecordArtist.selector, ARTIST));
        _known(pins);
        require(
            Reads.knownIdentity(
                address(metadata), address(core), originalChain, _historical(), ARTIST, CAP
            ) == REGISTRATION,
            "unknown selected artist never falls back to known original"
        );
        bytes memory healthy = abi.encode(address(0), uint256(0), uint256(0), REGISTRATION);
        _authority(1, healthy);
        require(_known(pins) == REGISTRATION, "same selected artist after registration repair");
        for (uint256 i; i < 3; ++i) {
            uint256[4] memory words;
            words[3] = uint256(REGISTRATION);
            words[i] = i == 0 ? uint256(1) << 160 : 256;
            _authority(1, abi.encode(words));
            vm.expectRevert(
                abi.encodeWithSelector(
                    Reads.ArtistIdentityReadFailed.selector, address(owners[1][2])
                )
            );
            _known(pins);
            _authority(1, healthy);
            require(_known(pins) == REGISTRATION, "same artist after authority word repair");
        }
        uint256[4] memory lengths = [uint256(0), 127, 129, 160];
        for (uint256 i; i < lengths.length; ++i) {
            _authority(1, new bytes(lengths[i]));
            vm.expectRevert(
                abi.encodeWithSelector(
                    Reads.ArtistIdentityReadFailed.selector, address(owners[1][2])
                )
            );
            _known(pins);
            _authority(1, healthy);
            require(_known(pins) == REGISTRATION, "same artist after authority length repair");
        }
        _authority(1, abi.encode(address(0), uint256(0), uint256(0), REGISTRATION));
        require(_known(pins) == REGISTRATION, "same identity with exact canonical response");
    }

    function testOperativeSignerStatusAndClassNeverReplaceImmutableRegistration() public {
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        Reads.Pins memory pins = _current();
        uint8[6] memory statuses = [uint8(0), 1, 2, 3, 4, 255];
        for (uint256 i; i < statuses.length; ++i) {
            _authority(
                1,
                abi.encode(
                    i == 0 ? address(0) : address(uint160(i)),
                    uint256(statuses[i]),
                    uint256(statuses[statuses.length - i - 1]),
                    REGISTRATION
                )
            );
            require(
                _known(pins) == REGISTRATION, "operative fields do not rename historical artist"
            );
        }
    }

    function testHistoricalReadsRetainOriginalWhileCurrentFailsClosedAndCapsAreUnchanged() public {
        _assertCurrent(0);
        Reads.Pins memory original = _historical();
        _pointer(ARTIST_POINTER, address(registries[1]));
        _assertCurrent(1);
        owners[1][6].answer(abi.encodeWithSelector(COMPLETE), abi.encode(bytes32(0)));
        vm.expectRevert(abi.encodeWithSelector(M.MetadataHostNotSelected.selector));
        _current();
        require(
            Reads.knownIdentity(
                address(metadata), address(core), originalChain, original, ARTIST, CAP
            ) == REGISTRATION,
            "old historical API still follows immutable original"
        );
        owners[1][6].answer(abi.encodeWithSelector(COMPLETE), abi.encode(COMPLETION));
        _assertCurrent(1);
        vm.expectRevert(abi.encodeWithSelector(Reads.InvalidArtistIdentityContext.selector));
        Reads.resolveCurrent(address(metadata), address(core), originalChain, 0);
        _assertCurrent(1);
        vm.expectRevert(abi.encodeWithSelector(Reads.InvalidArtistIdentityContext.selector));
        Reads.resolveCurrent(
            address(metadata), address(core), originalChain, uint256(type(uint64).max) + 1
        );
        _assertCurrent(1);
        bytes memory input = abi.encodeCall(this.currentProbe, ());
        (bool ok, bytes memory output) = address(this).staticcall{ gas: 100000 }(input);
        require(
            !ok
                && keccak256(output)
                    == keccak256(
                        abi.encodeWithSelector(
                            Reads.ArtistIdentityReadFailed.selector, address(metadata)
                        )
                    ),
            "original 200k cap rejects insufficient parent budget"
        );
        (ok, output) = address(this).staticcall{ gas: 5000000 }(input);
        require(
            ok && abi.decode(output, (bytes32)) == REGISTRATION,
            "same input with sufficient parent budget"
        );
    }

    function currentProbe() external view returns (bytes32) {
        return _known(_current());
    }
}
