// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamArtistIdentityAuthority
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol";
import {
    StreamArtistExtensionFactory
} from "../../../smart-contracts/domains/artist/StreamArtistExtensionFactory.sol";
import {
    StreamArtistIdentityCreationPart
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityCreationPart.sol";
import {
    StreamArtistEstateCreationPart
} from "../../../smart-contracts/domains/artist/StreamArtistEstateCreationPart.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamModuleRegistry
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

interface IdentityTerminalVm {
    function getCode(string calldata artifact) external view returns (bytes memory);
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
}

contract IdentityTerminalGovernance {
    bool private active;
    bytes32 private action;
    bytes32 private scope;
    bytes32 private beforeHash;
    bytes32 private afterHash;

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (active, action, 0, scope, beforeHash, afterHash);
    }

    function setAction(bytes32 a, bytes32 s, bytes32 b, bytes32 n) external {
        active = true;
        action = a;
        scope = s;
        beforeHash = b;
        afterHash = n;
    }
}

contract IdentityTerminalModules {
    address public immutable governanceExecutor;

    constructor(address authority) {
        governanceExecutor = authority;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamModuleRegistry).interfaceId;
    }
}

contract IdentityTerminalCore {
    address public immutable modules;

    constructor(address registry) {
        modules = registry;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        require(kind == keccak256("MODULE_REGISTRY"), "exact constructor pointer");
        return (
            modules,
            modules.codehash,
            false,
            kind,
            type(IStreamModuleRegistry).interfaceId,
            modules,
            1,
            bytes32(0),
            bytes32(0),
            1
        );
    }
}

contract IdentityTerminalManager {
    address public immutable core;
    address public immutable moduleRegistry;
    address public immutable governanceAuthority;

    constructor(address c, address m, address g) {
        core = c;
        moduleRegistry = m;
        governanceAuthority = g;
    }
}

/// @notice Actual Factory, compiler-derived carriers, three original children and Identity owner.
/// @dev Core, Manager, Registry/Archive addresses, governance facts and this Coordinator are explicit
/// typed boundaries. This is not a seven-owner migration, actual Executor/Safe or current-graph test.
/// No owner storage is seeded or overwritten. Registration/timing use original production writers.
contract StreamArtistIdentityTerminalReadsTest is CharacterizationTestBase {
    IdentityTerminalVm private constant ivm = IdentityTerminalVm(address(vm));
    StreamArtistIdentityAuthority private owner;
    StreamArtistExtensionFactory private factory;
    IdentityTerminalGovernance private governance;
    IdentityTerminalCore private core;
    IdentityTerminalManager private manager;
    T.SuiteConfiguration private suite;
    address private constant REGISTRY = address(0x701);
    address private constant ARCHIVE = address(0x702);
    address private constant ARTIST = address(0x703);

    function setUp() public {
        vm.warp(1_000_000);
        governance = new IdentityTerminalGovernance();
        IdentityTerminalModules modules = new IdentityTerminalModules(address(governance));
        core = new IdentityTerminalCore(address(modules));
        manager = new IdentityTerminalManager(address(core), address(modules), address(governance));
        address[4] memory parts;
        for (uint8 i; i < 4; ++i) {
            parts[i] = _create(
                i < 2 ? "StreamArtistIdentityCreationPart" : "StreamArtistEstateCreationPart",
                abi.encode(uint8(i % 2))
            );
        }
        factory = StreamArtistExtensionFactory(
            _create("StreamArtistExtensionFactory", abi.encode(parts))
        );
        address predicted = ivm.computeCreateAddress(address(this), ivm.getNonce(address(this)));
        address[6] memory pins =
            [predicted, REGISTRY, address(this), ARCHIVE, address(core), address(manager)];
        address[3] memory children;
        for (uint8 i; i < 3; ++i) {
            children[i] = factory.deployIdentity(i + 1, pins);
        }
        owner = StreamArtistIdentityAuthority(
            _create(
                "StreamArtistIdentityAuthority",
                abi.encode(
                    REGISTRY,
                    address(this),
                    ARCHIVE,
                    address(core),
                    address(manager),
                    address(factory),
                    children
                )
            )
        );
        require(address(owner) == predicted, "original CREATE prediction");
        suite.registry = REGISTRY;
        suite.archive = ARCHIVE;
        suite.core = address(core);
        suite.mintManager = address(manager);
        suite.owners[2] = address(owner);
    }

    function authorityHydrationSuite() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }

    function _create(string memory name, bytes memory args) private returns (address result) {
        bytes memory code = bytes.concat(
            ivm.getCode(string.concat("smart-contracts/domains/artist/", name, ".sol:", name)), args
        );
        require(code.length <= 49_152, "actual initcode admission");
        assembly ("memory-safe") {
            result := create(0, add(code, 32), mload(code))
            if iszero(result) {
                let p := mload(64)
                returndatacopy(p, 0, returndatasize())
                revert(p, returndatasize())
            }
        }
        require(result.code.length != 0 && result.code.length <= 24_576, "actual runtime admission");
    }

    function _read(bytes memory data) private view returns (bytes memory result) {
        bool ok;
        (ok, result) = address(owner).staticcall(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
    }

    function _same(bytes memory a, bytes memory b) private pure {
        require(a.length == b.length && keccak256(a) == keccak256(b), "literal ABI bytes");
    }

    function _register(bytes memory document, string memory uri, string memory name)
        private
        returns (bytes32 id)
    {
        uint256 nonce = owner.nextRegistrationNonce();
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ID_V1"),
                block.chainid,
                REGISTRY,
                ARTIST,
                keccak256(document),
                nonce
            )
        );
        require(
            owner.registerIdentity(
                T.ActionContext(1, ARTIST, owner.ownerStateSnapshotV2()),
                ARTIST,
                keccak256(document),
                uri,
                document,
                name
            ) == id,
            "original registration domain"
        );
    }

    function testActualConstructorChildrenAndNonceIdentityStayOriginal() public view {
        require(
            owner.core() == address(core) && owner.mintManager() == address(manager),
            "owner dependencies"
        );
        require(
            owner.artistWindowAuthority() == address(governance)
                && owner.operationCoordinator() == address(this),
            "canonical bindings"
        );
        address[3] memory children = [
            owner.identityWriterExtension(),
            owner.identityEstateExtension(),
            owner.identityRecoveryExtension()
        ];
        for (uint8 i; i < 3; ++i) {
            StreamArtistExtensionFactory.Birth memory b = factory.birth(children[i]);
            require(
                b.kind == i + 1 && b.host == address(owner)
                    && b.runtimeCodeHash == children[i].codehash,
                "actual original birth"
            );
        }
        require(
            owner.identityAdjudicationExtension() == ivm.computeCreateAddress(address(owner), 1),
            "nonce1 adjudication"
        );
        require(
            owner.identityRewindExtension() == ivm.computeCreateAddress(address(owner), 2),
            "nonce2 rewind"
        );
    }

    function testRegisteredDynamicIdentityReturnsExactOriginalBytes() public {
        _document(
            bytes("01234567890123456789012345678901234"),
            "ipfs://identity-33",
            "An original artist name"
        );
    }

    function testFuzzRegisteredDocumentReturnBytes(bytes memory data, uint8 padding) public {
        uint256 n = 1 + uint256(padding);
        bytes memory document = new bytes(n);
        for (uint256 i; i < n; ++i) {
            document[i] = data.length == 0 ? bytes1(uint8(i)) : data[i % data.length];
        }
        _document(document, "ipfs://original", "Original");
    }

    function _document(bytes memory document, string memory uri, string memory name) private {
        bytes32 id = _register(document, uri, name);
        T.Identity memory expected = T.Identity(
            ARTIST,
            1,
            1,
            uint64(block.timestamp),
            uint64(block.timestamp),
            keccak256(document),
            uri,
            name,
            0
        );
        _same(_read(abi.encodeCall(owner.identity, (id))), abi.encode(expected));
        _same(abi.encode(owner.identity(id)), abi.encode(expected));
        _same(
            _read(abi.encodeCall(owner.identityDocumentBytes, (keccak256(document)))),
            abi.encode(document)
        );
        _same(_read(abi.encodeCall(owner.identityRecordBytes, (id))), abi.encode(document));
        _same(
            _read(abi.encodeCall(owner.operativeIdentityMetadata, (id))),
            abi.encode(keccak256(document), uri, name)
        );
        _same(
            _read(abi.encodeCall(owner.artistDisplayName, (id))),
            abi.encode(name, keccak256(document))
        );
        require(owner.nextRegistrationNonce() == 1, "single original writer");
    }

    function testOriginalEmptyAndMixedDynamicResultsAreCanonical() public view {
        T.Identity memory blank;
        _same(_read(abi.encodeCall(owner.identity, (bytes32(uint256(90))))), abi.encode(blank));
        _same(
            _read(abi.encodeCall(owner.signatureBundle, (bytes32(uint256(91))))),
            abi.encode(bytes(""))
        );
        _same(
            _read(abi.encodeCall(owner.guardianSet, (bytes32(uint256(92))))),
            abi.encode(new address[](0), uint32(0), uint64(0), bytes32(0))
        );
        (bool ok, bytes memory reason) = address(owner)
            .staticcall(abi.encodeCall(owner.recordPreimageBytes, (bytes32(uint256(93)))));
        require(!ok, "unknown record preimage is unavailable");
        _same(
            reason,
            abi.encodeWithSignature("ArtistPayloadUnavailable(bytes32)", bytes32(uint256(93)))
        );
    }

    function testOriginalTimingWriterYieldsExactCheckpointAndEntry() public {
        bytes32 schema = keccak256("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1");
        uint256[12] memory rawConfig;
        _same(
            _read(abi.encodeCall(owner.recoveredTimingCheckpoint, ())),
            abi.encode(schema, uint16(1), uint256(0), bytes32(0), keccak256(abi.encode(rawConfig)))
        );
        bytes32 parameter = keccak256("ARTIST_ROTATION_CONTEST_SECONDS");
        bytes32 action = keccak256("original timing action");
        bytes32 oldHash = _windowHash(parameter, 7 days, 1);
        bytes32 newHash = _windowHash(parameter, 8 days, 2);
        governance.setAction(
            action,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_WINDOW_SCOPE_V1"),
                    block.chainid,
                    address(owner),
                    parameter
                )
            ),
            oldHash,
            newHash
        );
        owner.configureArtistWindow(address(governance), parameter, 8 days, 1);
        TM.Input memory change = TM.Input(
            parameter,
            action,
            keccak256(abi.encode(action, parameter, oldHash, newHash)),
            oldHash,
            newHash,
            7 days,
            8 days,
            72 hours,
            1,
            2
        );
        TM.Entry memory entry =
            TM.Entry(block.chainid, address(owner), 0, change, bytes32(0), bytes32(0));
        entry.commitment = keccak256(abi.encode(schema, uint16(1), entry));
        _same(_read(abi.encodeCall(owner.recoveredTimingEntryAt, (uint256(0)))), abi.encode(entry));
        rawConfig[0] = 8 days;
        rawConfig[7] = 2;
        _same(
            _read(abi.encodeCall(owner.recoveredTimingCheckpoint, ())),
            abi.encode(
                schema, uint16(1), uint256(1), entry.commitment, keccak256(abi.encode(rawConfig))
            )
        );
        (bool ok, bytes memory reason) =
            address(owner).staticcall(abi.encodeCall(owner.recoveredTimingEntryAt, (uint256(1))));
        require(!ok, "out of range entry refused");
        _same(reason, abi.encodeWithSignature("Panic(uint256)", uint256(0x32)));
    }

    function _windowHash(bytes32 p, uint64 v, uint64 revision) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_WINDOW_STATE_V1"),
                block.chainid,
                address(owner),
                p,
                v,
                uint64(72 hours),
                revision
            )
        );
    }

    function testMalformedReadsDoNotBypassDecoderOrMutateOwner() public {
        bytes32 beforeHash = keccak256(abi.encode(owner.ownerStateSnapshotV2()));
        (bool truncated,) = address(owner).staticcall(abi.encodePacked(owner.identity.selector));
        require(!truncated, "missing original argument refused");
        (bool noncanonical,) = address(owner)
            .staticcall(
                abi.encodePacked(
                    owner.authorityNonceWordAt.selector,
                    abi.encode(uint256(256), bytes32(uint256(1)), uint256(0))
                )
            );
        require(!noncanonical, "uint8 bound retained");
        (bool unknown,) = address(owner).staticcall(hex"ffffffff");
        require(!unknown, "unknown selector refused");
        require(
            beforeHash == keccak256(abi.encode(owner.ownerStateSnapshotV2())),
            "reads preserve snapshot"
        );
        _same(
            _read(abi.encodeCall(owner.identityDocumentBytes, (bytes32(uint256(1))))),
            abi.encode(bytes(""))
        );
    }

    function testRecoveredReadRequiresActualProvenanceAndFixedSuite() public {
        AH.Query memory q;
        q.artistId = bytes32(uint256(1));
        RH.OwnerProvenance memory p;
        (bool ok, bytes memory reason) =
            address(owner).staticcall(abi.encodeCall(owner.recoveredIdentityHydrationRaw, (q, p)));
        require(!ok, "raw missing provenance refused");
        _same(reason, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector));
        (ok, reason) = address(owner)
            .staticcall(abi.encodeCall(owner.recoveredAuthorityHydrationState, (q, p)));
        require(!ok, "encoded missing provenance refused");
        _same(reason, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector));
        (ok, reason) = address(owner)
            .staticcall(
                abi.encodeCall(owner.recoveredHydrationAuxiliaryPoint, (bytes32(0), bytes32(0)))
            );
        require(!ok, "unknown auxiliary kind refused");
        _same(reason, abi.encodeWithSignature("InvalidRecoveredIdentity(bytes32)", bytes32(0)));
        suite.owners[2] = address(0xdead);
        (ok, reason) = address(owner)
            .staticcall(
                abi.encodeCall(owner.recoveredHydrationAuxiliaryPoint, (bytes32(0), bytes32(0)))
            );
        require(!ok, "wrong fixed owner refused");
        _same(reason, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector));
        suite.owners[2] = address(owner);
        (ok, reason) = address(owner)
            .staticcall(
                abi.encodeCall(owner.recoveredHydrationAuxiliaryPoint, (bytes32(0), bytes32(0)))
            );
        require(!ok, "unknown auxiliary kind refused");
        _same(reason, abi.encodeWithSignature("InvalidRecoveredIdentity(bytes32)", bytes32(0)));
    }

    function testOriginalWriterGuardsAndExactRetryRemainIntact() public {
        bytes memory document = bytes("original retry document");
        T.ActionContext memory c = T.ActionContext(1, ARTIST, owner.ownerStateSnapshotV2());
        bytes32 beforeHash = keccak256(abi.encode(c.expected));
        vm.prank(address(0xbeef));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(0xbeef)));
        owner.registerIdentity(c, ARTIST, keccak256(document), "ipfs://retry", document, "Original");
        c.operationId = 2;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidOperation.selector, uint16(2)));
        owner.registerIdentity(c, ARTIST, keccak256(document), "ipfs://retry", document, "Original");
        require(
            beforeHash == keccak256(abi.encode(owner.ownerStateSnapshotV2()))
                && owner.nextRegistrationNonce() == 0,
            "failed guards preserve state"
        );
        c.operationId = 1;
        bytes32 id = owner.registerIdentity(
            c, ARTIST, keccak256(document), "ipfs://retry", document, "Original"
        );
        require(
            owner.identity(id).authorityAddress == ARTIST && owner.nextRegistrationNonce() == 1,
            "same arguments valid original writer"
        );
    }
}
