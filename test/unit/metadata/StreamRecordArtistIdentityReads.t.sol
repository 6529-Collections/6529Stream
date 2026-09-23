// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/records/StreamRecordArtistIdentityReads.sol";

interface RecordArtistVm {
    function expectRevert() external;
    function expectRevert(bytes calldata reason) external;
    function etch(address target, bytes calldata code) external;
    function chainId(uint256 chain) external;
}

/// @dev Explicit typed-source response fixture, not an actual artist owner implementation.
contract RecordArtistReadFixture {
    mapping(bytes4 => bytes) private answers;
    bool private fail;

    function set(bytes4 selector, bytes memory value) external {
        answers[selector] = value;
    }

    function setFail(bool value) external {
        fail = value;
    }

    fallback() external {
        require(!fail, "fixture outage");
        bytes memory data = answers[msg.sig];
        assembly ("memory-safe") { return(add(data, 32), mload(data)) }
    }
}

/// @dev Same inherited getters/storage as the facade fixture, distinct runtime identity.
contract RecordArtistReadReplacement is RecordArtistReadFixture {
    function differentRuntime() external pure returns (uint256) {
        return 1;
    }
}

contract StreamRecordArtistIdentityReadsTest {
    RecordArtistVm private constant vm =
        RecordArtistVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecordArtistReadFixture private metadata;
    RecordArtistReadFixture private facade;
    RecordArtistReadFixture private coordinator;
    RecordArtistReadFixture private identity;
    address private constant CORE = address(0xC0E);
    bytes32 private constant ARTIST = bytes32(uint256(33));
    bytes32 private constant REGISTRATION = bytes32(uint256(77));
    uint256 private constant CAP = 200000;
    bytes4 private constant REGISTRY = bytes4(keccak256("artistRegistry()"));
    bytes4 private constant CORE_READ = bytes4(keccak256("core()"));
    bytes4 private constant COORDINATOR = bytes4(keccak256("operationCoordinator()"));
    bytes4 private constant CHAIN = bytes4(keccak256("deploymentChainId()"));
    bytes4 private constant SUITE = bytes4(keccak256("suiteConfiguration()"));
    bytes4 private constant STATE = bytes4(keccak256("authorityState(bytes32)"));

    function setUp() public {
        metadata = new RecordArtistReadFixture();
        facade = new RecordArtistReadFixture();
        coordinator = new RecordArtistReadFixture();
        identity = new RecordArtistReadFixture();
        metadata.set(REGISTRY, abi.encode(address(facade)));
        metadata.set(
            bytes4(keccak256("artistRegistryCodeHash()")), abi.encode(address(facade).codehash)
        );
        facade.set(CORE_READ, abi.encode(CORE));
        facade.set(COORDINATOR, abi.encode(address(coordinator)));
        coordinator.set(CHAIN, abi.encode(block.chainid));
        coordinator.set(SUITE, _suite());
        identity.set(CORE_READ, abi.encode(CORE));
        identity.set(REGISTRY, abi.encode(address(facade)));
        identity.set(COORDINATOR, abi.encode(address(coordinator)));
        identity.set(CHAIN, abi.encode(block.chainid));
        identity.set(STATE, abi.encode(address(0xA), uint256(1), uint256(1), REGISTRATION));
    }

    function _suite() private view returns (bytes memory) {
        // Literal permanent17-word order, independent of the production struct decoder.
        uint256[17] memory words;
        words[0] = uint160(address(facade));
        words[1] = 0xA1;
        words[2] = 0xA2;
        words[3] = 0xA3;
        words[4] = uint160(address(identity));
        words[5] = 0xA5;
        words[6] = 0xA6;
        words[7] = 0xA7;
        words[8] = 0xA8;
        words[9] = uint160(CORE);
        words[10] = 0xAA;
        words[11] = 0xAB;
        words[12] = 0xAC;
        words[13] = 0xAD;
        words[14] = 0xAE;
        words[15] = type(uint256).max;
        words[16] = 0xAF;
        return abi.encode(words);
    }

    function _pins() private view returns (StreamRecordArtistIdentityReads.Pins memory) {
        return StreamRecordArtistIdentityReads.resolve(address(metadata), CORE, block.chainid, CAP);
    }

    function _known(StreamRecordArtistIdentityReads.Pins memory pins)
        private
        view
        returns (bytes32)
    {
        return StreamRecordArtistIdentityReads.knownIdentity(
            address(metadata), CORE, block.chainid, pins, ARTIST, CAP
        );
    }

    function testExactOwnersTwoJoinAndAllRuntimePins() public view {
        StreamRecordArtistIdentityReads.Pins memory p = _pins();
        require(
            p.targets[0] == address(facade) && p.targets[1] == address(coordinator)
                && p.targets[2] == address(identity),
            "actual join"
        );
        require(
            p.codeHashes[0] == address(facade).codehash
                && p.codeHashes[1] == address(coordinator).codehash
                && p.codeHashes[2] == address(identity).codehash,
            "runtime pins"
        );
        require(_known(p) == REGISTRATION, "immutable registration only");
    }

    function testInitialResolveRejectsCoherentFacadeWithWrongMetadataRuntimePin() public {
        bytes memory originalCode = address(facade).code;
        RecordArtistReadReplacement replacement = new RecordArtistReadReplacement();
        vm.etch(address(facade), address(replacement).code);
        // Getter-compatible runtime uses the untouched original storage. These complete
        // readbacks show the negative is not merely a malformed/empty facade response.
        (bool ok, bytes memory data) = address(facade).staticcall(abi.encodeWithSignature("core()"));
        require(ok && abi.decode(data, (address)) == CORE, "same coherent Core");
        (ok, data) = address(facade).staticcall(abi.encodeWithSignature("operationCoordinator()"));
        require(
            ok && abi.decode(data, (address)) == address(coordinator), "same coherent Coordinator"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRecordArtistIdentityReads.ArtistIdentityDependencyChanged.selector,
                address(facade)
            )
        );
        _pins();
        vm.etch(address(facade), originalCode);
        require(_known(_pins()) == REGISTRATION, "same original graph restored");
        metadata.set(bytes4(keccak256("artistRegistryCodeHash()")), new bytes(31));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRecordArtistIdentityReads.ArtistIdentityReadFailed.selector, address(metadata)
            )
        );
        _pins();
    }

    function testKnownIdentitySurvivesAllCanonicalStatusAndSignerChanges() public {
        StreamRecordArtistIdentityReads.Pins memory p = _pins();
        uint8[6] memory statuses = [uint8(0), 1, 2, 3, 4, 255];
        for (uint256 i; i < statuses.length; ++i) {
            identity.set(
                STATE,
                abi.encode(address(0), uint256(statuses[i]), uint256(statuses[i]), REGISTRATION)
            );
            require(_known(p) == REGISTRATION, "no active/current signer requirement");
        }
    }

    function testUnknownIdentityAndZeroIdRejectWithSameIdentityRetry() public {
        StreamRecordArtistIdentityReads.Pins memory p = _pins();
        identity.set(STATE, abi.encode(address(0xA), uint256(1), uint256(1), bytes32(0)));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRecordArtistIdentityReads.UnknownRecordArtist.selector, ARTIST
            )
        );
        _known(p);
        identity.set(STATE, abi.encode(address(0), uint256(0), uint256(0), REGISTRATION));
        require(_known(p) == REGISTRATION, "known registration with zero operative fields");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRecordArtistIdentityReads.UnknownRecordArtist.selector, bytes32(0)
            )
        );
        StreamRecordArtistIdentityReads.knownIdentity(
            address(metadata), CORE, block.chainid, p, 0, CAP
        );
    }

    function testMalformedEveryAuthorityWordAndExactReturnLengths() public {
        StreamRecordArtistIdentityReads.Pins memory p = _pins();
        for (uint256 i; i < 3; ++i) {
            uint256[4] memory words;
            words[3] = uint256(REGISTRATION);
            words[i] = i == 0 ? 1 << 160 : 256;
            identity.set(STATE, abi.encode(words));
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamRecordArtistIdentityReads.ArtistIdentityReadFailed.selector,
                    address(identity)
                )
            );
            _known(p);
        }
        uint256[5] memory lengths = [uint256(0), 32, 127, 129, 65536];
        for (uint256 i; i < lengths.length; ++i) {
            identity.set(STATE, new bytes(lengths[i]));
            vm.expectRevert();
            _known(p);
        }
        identity.set(STATE, abi.encode(address(0), uint256(255), uint256(255), REGISTRATION));
        require(_known(p) == REGISTRATION, "same artist healthy retry");
    }

    function testEverySuiteAddressCanonicalAndTrailingBytesRejected() public {
        for (uint256 i; i < 17; ++i) {
            if (i == 15) continue;
            bytes memory data = _suite();
            assembly ("memory-safe") { mstore(add(add(data, 32), mul(i, 32)), shl(160, 1)) }
            coordinator.set(SUITE, data);
            vm.expectRevert();
            _pins();
        }
        coordinator.set(SUITE, bytes.concat(_suite(), bytes32(0)));
        vm.expectRevert();
        _pins();
        coordinator.set(SUITE, new bytes(512));
        vm.expectRevert();
        _pins();
        coordinator.set(SUITE, _suite());
        require(_known(_pins()) == REGISTRATION, "full-width class hash permitted");
    }

    function testReciprocalCoreFacadeCoordinatorAndChainCannotBeSubstituted() public {
        RecordArtistReadFixture[5] memory targets =
            [facade, identity, identity, identity, coordinator];
        bytes4[5] memory selectors = [CORE_READ, CORE_READ, REGISTRY, COORDINATOR, CHAIN];
        bytes[5] memory healthy = [
            abi.encode(CORE),
            abi.encode(CORE),
            abi.encode(address(facade)),
            abi.encode(address(coordinator)),
            abi.encode(block.chainid)
        ];
        for (uint256 i; i < 5; ++i) {
            targets[i].set(selectors[i], abi.encode(uint256(0xBAD)));
            vm.expectRevert();
            _pins();
            targets[i].set(selectors[i], healthy[i]);
            require(_known(_pins()) == REGISTRATION, "restored reciprocal binding");
        }
        identity.set(CHAIN, abi.encode(block.chainid + 1));
        vm.expectRevert();
        _pins();
        identity.set(CHAIN, abi.encode(block.chainid));
        bytes memory data = _suite();
        assembly ("memory-safe") { mstore(add(data, 32), 0) }
        coordinator.set(SUITE, data);
        vm.expectRevert();
        _pins();
        data = _suite();
        assembly ("memory-safe") { mstore(add(data, 320), 0) }
        coordinator.set(SUITE, data);
        vm.expectRevert();
        _pins();
    }

    function testPinnedAddressAndRuntimeDriftRejectsThenSameRecordRetries() public {
        StreamRecordArtistIdentityReads.Pins memory p = _pins();
        for (uint256 i; i < 3; ++i) {
            p.codeHashes[i] ^= bytes32(uint256(1));
            vm.expectRevert();
            _known(p);
            p.codeHashes[i] ^= bytes32(uint256(1));
            address old = p.targets[i];
            p.targets[i] = address(0xBAD);
            vm.expectRevert();
            _known(p);
            p.targets[i] = old;
        }
        bytes memory code = address(identity).code;
        vm.etch(address(identity), hex"00");
        vm.expectRevert();
        _known(p);
        vm.etch(address(identity), code);
        require(_known(p) == REGISTRATION, "restored same historical hash");
        metadata.set(REGISTRY, abi.encode(address(0xBAD)));
        vm.expectRevert();
        _known(p);
        metadata.set(REGISTRY, abi.encode(address(facade)));
        require(_known(p) == REGISTRATION, "restore actual selected facade");
    }

    function testAddressReadCanonicalCapAndProviderOutage() public {
        StreamRecordArtistIdentityReads.Pins memory p = _pins();
        metadata.set(REGISTRY, abi.encode(uint256(1) << 160));
        vm.expectRevert();
        _known(p);
        metadata.set(REGISTRY, abi.encode(address(facade), uint256(0)));
        vm.expectRevert();
        _known(p);
        metadata.set(REGISTRY, abi.encode(address(facade)));
        identity.setFail(true);
        vm.expectRevert();
        _known(p);
        identity.setFail(false);
        require(_known(p) == REGISTRATION, "same artist outage recovery");
        vm.expectRevert();
        StreamRecordArtistIdentityReads.resolve(address(metadata), CORE, block.chainid, 0);
        vm.expectRevert();
        StreamRecordArtistIdentityReads.resolve(
            address(metadata), CORE, block.chainid, uint256(type(uint64).max) + 1
        );
        vm.expectRevert();
        StreamRecordArtistIdentityReads.resolve(address(metadata), CORE, block.chainid + 1, CAP);
    }

    function probe(StreamRecordArtistIdentityReads.Pins calldata p)
        external
        view
        returns (bytes32)
    {
        return _known(p);
    }

    function testInsufficientParentGasRevertsAndIdenticalHealthyCallSucceeds() public {
        StreamRecordArtistIdentityReads.Pins memory p = _pins();
        bytes memory input = abi.encodeCall(this.probe, (p));
        (bool ok, bytes memory reason) = address(this).staticcall{ gas: 100000 }(input);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamRecordArtistIdentityReads.ArtistIdentityReadFailed.selector,
                            address(metadata)
                        )
                    ),
            "class2 parent admission"
        );
        (ok, reason) = address(this).staticcall{ gas: 3000000 }(input);
        require(
            ok && abi.decode(reason, (bytes32)) == REGISTRATION, "same complete input healthy cap"
        );
    }
}
