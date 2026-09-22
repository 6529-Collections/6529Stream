// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistEconomicsHydrationTypes as Economics
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    StreamArtistRegistryWriterDeployment as Deployment
} from "../../../smart-contracts/domains/artist/StreamArtistRegistryWriterDeployment.sol";
import {
    StreamArtistRegistryWriterExtension as Writer
} from "../../../smart-contracts/domains/artist/StreamArtistRegistryWriterExtension.sol";
import {
    StreamArtistEntropyFindingHydrationTypes as Entropy,
    IStreamArtistEntropyFindingHydrationCoordinator
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as Authority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Readiness
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

contract RegistryWriterDeploymentHost {
    function deploy(address host, address coordinator) external returns (address) {
        return Deployment.deployWriter(host, coordinator);
    }

    function originalCreate(bytes memory initcode) external returns (address child) {
        assembly { child := create(0, add(initcode, 32), mload(initcode)) }
        if (child == address(0)) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function forward(address child, bytes calldata input) external returns (bytes memory) {
        (bool ok, bytes memory result) = child.delegatecall(input);
        if (!ok) assembly { revert(add(result, 32), mload(result)) }
        return result;
    }
}

/// @dev Records only the transport boundary; it does not admit Artist history.
contract RegistryWriterRecordingCoordinator {
    error DeliberateFailure(bytes32 marker);
    bytes public received;
    address public caller;
    uint256 public calls;
    bool public fail;

    function setFailure(bool value) external {
        fail = value;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        received = input;
        caller = msg.sender;
        calls++;
        if (fail) revert DeliberateFailure(keccak256("writer-failure"));
        return abi.encode(keccak256("writer-result"));
    }
}

interface RegistryWriterVm {
    function getNonce(address) external view returns (uint64);
    function deal(address, uint256) external;
    function getCode(string calldata) external view returns (bytes memory);
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function prank(address) external;
    function assume(bool) external;
}

contract StreamArtistRegistryWriterDeploymentCapacityTest {
    RegistryWriterVm private constant vm =
        RegistryWriterVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RegistryWriterDeploymentHost internal host;
    RegistryWriterRecordingCoordinator internal coordinator;
    address internal writer;

    function setUp() public {
        host = new RegistryWriterDeploymentHost();
        coordinator = new RegistryWriterRecordingCoordinator();
        writer = host.deploy(address(host), address(coordinator));
    }

    function testCreatePreservesHostNonceValueArgumentsAndRuntime() public {
        uint64 beforeNonce = vm.getNonce(address(host));
        address expected = _createAddress(address(host), beforeNonce);
        vm.deal(address(host), 7 ether);
        address child = host.deploy(address(host), address(coordinator));
        assertEq(child, expected);
        assertEq(vm.getNonce(address(host)), beforeNonce + 1);
        assertEq(address(host).balance, 7 ether);
        assertEq(child.balance, 0);
        bytes memory code = vm.getCode(
            "smart-contracts/domains/artist/StreamArtistRegistryWriterExtension.sol:StreamArtistRegistryWriterExtension"
        );
        bytes memory initcode = bytes.concat(code, abi.encode(address(host), address(coordinator)));
        assertLe(initcode.length, 49_152);
        address original = host.originalCreate(initcode);
        assertEq(original, _createAddress(address(host), beforeNonce + 1));
        assertEq(child.code, original.code);
        assertLe(child.code.length, 24_576);
    }

    function testConstructorRefusalsDoNotConsumeHostNonceAndRetryIsIdentical() public {
        uint64 nonce = vm.getNonce(address(host));
        address expected = _createAddress(address(host), nonce);
        address[4] memory hosts = [address(0), address(host), address(coordinator), expected];
        address[4] memory coordinators =
            [address(coordinator), address(0), address(coordinator), address(coordinator)];
        for (uint256 i; i < 4; ++i) {
            vm.expectRevert(T.InvalidBinding.selector);
            host.deploy(hosts[i], coordinators[i]);
            assertEq(vm.getNonce(address(host)), nonce);
            assertEq(expected.code.length, 0);
        }
        assertEq(host.deploy(address(host), address(coordinator)), expected);
    }

    function testFullNestedPayloadActorAndCoordinatorCaller() public {
        Entropy.Request memory request = _request();
        address actor = address(0xA11CE);
        bytes memory input =
            abi.encodeCall(Writer.hydrateArtistAuthorityWithEntropyFindings, (request));
        bytes memory expected = _expected(actor, request);
        vm.prank(actor);
        bytes memory result = host.forward(writer, input);
        assertEq(result, abi.encode(keccak256("writer-result")));
        assertEq(coordinator.received(), expected);
        assertEq(coordinator.caller(), address(host));
        assertEq(coordinator.calls(), 1);
    }

    function testReadinessUsesOriginalSelectorAndFullPayloadWithRollback() public {
        Readiness.Request memory request = _readiness();
        address actor = address(0xB0B);
        bytes memory input = abi.encodeCall(Writer.hydrateArtistAuthorityWithReadiness, (request));
        bytes4 selector = bytes4(
            keccak256(
                "coordinateHydrateArtistAuthorityWithReadiness(address,(((uint256,bytes32,uint256,(bytes32,(bytes32,uint64,bytes32,bytes32),bytes32,uint256,bytes32,uint256)[7],(bytes32,bytes32)[][7],(bytes32,bytes32)[]),(uint256,address,bytes32,uint8,uint256,bytes32)[]),((uint256,uint8,bytes32,bytes32,bytes32,bytes32,string),uint256)[]))"
            )
        );
        bytes memory expected = bytes.concat(selector, abi.encode(actor, request));
        coordinator.setFailure(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                RegistryWriterRecordingCoordinator.DeliberateFailure.selector,
                keccak256("writer-failure")
            )
        );
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.calls(), 0);
        coordinator.setFailure(false);
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.received(), expected);
        assertEq(coordinator.caller(), address(host));
        assertEq(coordinator.calls(), 1);
    }

    function testPublicationsUsesOriginalSelectorAndFullPayloadWithRollback() public {
        Readiness.Request memory request = _readiness();
        address actor = address(0xB0B);
        bytes memory input =
            abi.encodeCall(Writer.hydrateArtistAuthorityWithPublications, (request));
        bytes4 selector = bytes4(
            keccak256(
                "coordinateHydrateArtistAuthorityWithPublications(address,(((uint256,bytes32,uint256,(bytes32,(bytes32,uint64,bytes32,bytes32),bytes32,uint256,bytes32,uint256)[7],(bytes32,bytes32)[][7],(bytes32,bytes32)[]),(uint256,address,bytes32,uint8,uint256,bytes32)[]),((uint256,uint8,bytes32,bytes32,bytes32,bytes32,string),uint256)[]))"
            )
        );
        bytes memory expected = bytes.concat(selector, abi.encode(actor, request));
        coordinator.setFailure(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                RegistryWriterRecordingCoordinator.DeliberateFailure.selector,
                keccak256("writer-failure")
            )
        );
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.calls(), 0);
        coordinator.setFailure(false);
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.received(), expected);
        assertEq(coordinator.caller(), address(host));
        assertEq(coordinator.calls(), 1);
    }

    function testAuthorityUsesOriginalSelectorAndFullPayloadWithRollback() public {
        Authority.Request memory request = _request().authority;
        address actor = address(0xCAFE);
        bytes memory input = abi.encodeCall(Writer.hydrateArtistAuthority, (request));
        bytes memory expected = bytes.concat(
            bytes4(
                keccak256(
                    "coordinateHydrateArtistAuthority(address,(uint256,bytes32,uint256,(bytes32,(bytes32,uint64,bytes32,bytes32),bytes32,uint256,bytes32,uint256)[7],(bytes32,bytes32)[][7],(bytes32,bytes32)[]))"
                )
            ),
            abi.encode(actor, request)
        );
        coordinator.setFailure(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                RegistryWriterRecordingCoordinator.DeliberateFailure.selector,
                keccak256("writer-failure")
            )
        );
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.calls(), 0);
        coordinator.setFailure(false);
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.received(), expected);
        assertEq(coordinator.caller(), address(host));
        assertEq(coordinator.calls(), 1);
    }

    function testDelegationsUsesOriginalSelectorAndFullPayloadWithRollback() public {
        Authority.Request memory request = _request().authority;
        address actor = address(0xCAFE);
        bytes memory input = abi.encodeCall(Writer.hydrateArtistAuthorityWithDelegations, (request));
        bytes memory expected = bytes.concat(
            bytes4(
                keccak256(
                    "coordinateHydrateArtistAuthorityWithDelegations(address,(uint256,bytes32,uint256,(bytes32,(bytes32,uint64,bytes32,bytes32),bytes32,uint256,bytes32,uint256)[7],(bytes32,bytes32)[][7],(bytes32,bytes32)[]))"
                )
            ),
            abi.encode(actor, request)
        );
        coordinator.setFailure(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                RegistryWriterRecordingCoordinator.DeliberateFailure.selector,
                keccak256("writer-failure")
            )
        );
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.calls(), 0);
        coordinator.setFailure(false);
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.received(), expected);
        assertEq(coordinator.caller(), address(host));
        assertEq(coordinator.calls(), 1);
    }

    function testPayoutUsesOriginalSelectorAndFullPayloadWithRollback() public {
        Authority.Request memory request = _request().authority;
        address actor = address(0xCAFE);
        bytes memory input = abi.encodeCall(Writer.hydrateArtistAuthorityWithPayout, (request));
        bytes memory expected = bytes.concat(
            bytes4(
                keccak256(
                    "coordinateHydrateArtistAuthorityWithPayout(address,(uint256,bytes32,uint256,(bytes32,(bytes32,uint64,bytes32,bytes32),bytes32,uint256,bytes32,uint256)[7],(bytes32,bytes32)[][7],(bytes32,bytes32)[]))"
                )
            ),
            abi.encode(actor, request)
        );
        coordinator.setFailure(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                RegistryWriterRecordingCoordinator.DeliberateFailure.selector,
                keccak256("writer-failure")
            )
        );
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.calls(), 0);
        coordinator.setFailure(false);
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.received(), expected);
        assertEq(coordinator.caller(), address(host));
        assertEq(coordinator.calls(), 1);
    }

    function testEconomicsUsesOriginalSelectorAndFullPayloadWithRollback() public {
        Entropy.Request memory source = _request();
        Economics.Request memory request = Economics.Request(source.authority, source.economics);
        address actor = address(0xCAFE);
        bytes memory input = abi.encodeCall(Writer.hydrateArtistAuthorityWithEconomics, (request));
        bytes memory expected = bytes.concat(
            bytes4(
                keccak256(
                    "coordinateHydrateArtistAuthorityWithEconomics(address,((uint256,bytes32,uint256,(bytes32,(bytes32,uint64,bytes32,bytes32),bytes32,uint256,bytes32,uint256)[7],(bytes32,bytes32)[][7],(bytes32,bytes32)[]),(uint256,address,bytes32,uint8,uint256,bytes32)[]))"
                )
            ),
            abi.encode(actor, request)
        );
        coordinator.setFailure(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                RegistryWriterRecordingCoordinator.DeliberateFailure.selector,
                keccak256("writer-failure")
            )
        );
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.calls(), 0);
        coordinator.setFailure(false);
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.received(), expected);
        assertEq(coordinator.caller(), address(host));
        assertEq(coordinator.calls(), 1);
    }

    function testOriginalHostGuardRunsBeforeCoordinatorAndForeignHostFails() public {
        bytes memory input =
            abi.encodeCall(Writer.hydrateArtistAuthorityWithEntropyFindings, (_request()));
        vm.expectRevert(abi.encodeWithSelector(Writer.ExtensionWrongHost.selector, writer));
        Writer(writer).hydrateArtistAuthorityWithEntropyFindings(_request());
        RegistryWriterDeploymentHost foreign = new RegistryWriterDeploymentHost();
        vm.expectRevert(
            abi.encodeWithSelector(Writer.ExtensionWrongHost.selector, address(foreign))
        );
        foreign.forward(writer, input);
        assertEq(coordinator.calls(), 0);
    }

    function testCoordinatorRevertBubblesAndSamePayloadRetrySucceeds() public {
        Entropy.Request memory request = _request();
        bytes memory input =
            abi.encodeCall(Writer.hydrateArtistAuthorityWithEntropyFindings, (request));
        coordinator.setFailure(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                RegistryWriterRecordingCoordinator.DeliberateFailure.selector,
                keccak256("writer-failure")
            )
        );
        host.forward(writer, input);
        assertEq(coordinator.calls(), 0);
        coordinator.setFailure(false);
        assertEq(host.forward(writer, input), abi.encode(keccak256("writer-result")));
        assertEq(coordinator.received(), _expected(address(this), request));
        assertEq(coordinator.calls(), 1);
    }

    function testMalformedNestedOffsetRefusesBeforeCoordinatorAndRestores() public {
        bytes memory good =
            abi.encodeCall(Writer.hydrateArtistAuthorityWithEntropyFindings, (_request()));
        bytes memory bad = abi.decode(abi.encode(good), (bytes));
        // Top-level Request pointer starts at byte 4; make it point beyond the complete input.
        assembly { mstore(add(bad, 36), not(0)) }
        (bool ok,) = address(host).call(abi.encodeCall(host.forward, (writer, bad)));
        assertFalse(ok);
        assertEq(coordinator.calls(), 0);
        host.forward(writer, good);
        assertEq(coordinator.calls(), 1);
    }

    function testFuzzDynamicPayloadPreservesActorAndEveryByte(
        address actor,
        bytes memory uri,
        uint256 nonce
    ) public {
        vm.assume(actor != address(0));
        vm.assume(uri.length <= 1024);
        Entropy.Request memory request = _request();
        request.attestations[1].terms.statementURI = string(uri);
        request.attestations[1].nonce = nonce;
        bytes memory input =
            abi.encodeCall(Writer.hydrateArtistAuthorityWithEntropyFindings, (request));
        bytes memory expected = _expected(actor, request);
        vm.prank(actor);
        host.forward(writer, input);
        assertEq(coordinator.received(), expected);
        assertEq(coordinator.caller(), address(host));
    }

    function _createAddress(address creator, uint64 nonce) private pure returns (address) {
        require(nonce > 0 && nonce < 128, "one-byte test nonce");
        return
            address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", creator, uint8(nonce))))));
    }

    function assertEq(uint256 a, uint256 b) private pure {
        require(a == b, "integer equality");
    }

    function assertEq(address a, address b) private pure {
        require(a == b, "address equality");
    }

    function assertEq(bytes memory a, bytes memory b) private pure {
        require(a.length == b.length && keccak256(a) == keccak256(b), "complete byte equality");
    }

    function assertLe(uint256 a, uint256 b) private pure {
        require(a <= b, "capacity");
    }

    function assertFalse(bool value) private pure {
        require(!value, "must fail");
    }

    function _expected(address actor, Entropy.Request memory request)
        private
        pure
        returns (bytes memory)
    {
        bytes4 selector = bytes4(
            keccak256(
                "coordinateHydrateArtistAuthorityWithEntropyFindings(address,((uint256,bytes32,uint256,(bytes32,(bytes32,uint64,bytes32,bytes32),bytes32,uint256,bytes32,uint256)[7],(bytes32,bytes32)[][7],(bytes32,bytes32)[]),bool,bool,(uint256,address,bytes32,uint8,uint256,bytes32)[],((uint256,uint8,bytes32,bytes32,bytes32,bytes32,string),uint256)[]))"
            )
        );
        return bytes.concat(selector, abi.encode(actor, request));
    }

    function _readiness() private pure returns (Readiness.Request memory p) {
        Entropy.Request memory source = _request();
        p.economics.authority = source.authority;
        p.economics.economics = source.economics;
        p.attestations = source.attestations;
    }

    function _request() private pure returns (Entropy.Request memory p) {
        p.authority.bindingIndex = 19;
        p.authority.artistId = keccak256("artist");
        p.authority.collectionId = 77;
        for (uint256 i; i < 7; ++i) {
            p.authority.expectedSource[i].schema = bytes32(i + 100);
            p.authority.expectedSource[i].ownerState =
                T.Snapshot(bytes32(i + 10), uint64(i + 1), bytes32(i + 20), bytes32(i + 30));
            p.authority.expectedSource[i].replayRoot = bytes32(i + 200);
            p.authority.expectedSource[i].replayCount = i + 300;
            p.authority.expectedSource[i].nonceRoot = bytes32(i + 400);
            p.authority.expectedSource[i].nonceIndexCount = i + 500;
            p.authority.replayOrigins[i] = new Authority.Origin[](2);
            p.authority.replayOrigins[i][0] = Authority.Origin(bytes32(i + 600), bytes32(i + 700));
            p.authority.replayOrigins[i][1] = Authority.Origin(bytes32(i + 800), bytes32(i + 900));
        }
        p.authority.policies = new Authority.PolicyKey[](2);
        p.authority.policies[0] = Authority.PolicyKey(keccak256("phase1"), keccak256("policy1"));
        p.authority.policies[1] = Authority.PolicyKey(keccak256("phase2"), keccak256("policy2"));
        p.includePayout = true;
        p.publications = true;
        p.economics = new T.EconomicsConsent[](2);
        p.attestations = new Readiness.AttestationInput[](2);
        for (uint256 i; i < 2; ++i) {
            p.economics[i] = T.EconomicsConsent(
                77 + i,
                address(uint160(0x1000 + i)),
                bytes32(i + 1000),
                uint8(i + 1),
                i + 1100,
                bytes32(i + 1200)
            );
            p.attestations[i].terms = T.Attestation(
                77 + i,
                uint8(i + 1),
                bytes32(i + 1300),
                bytes32(i + 1400),
                bytes32(i + 1500),
                bytes32(i + 1600),
                i == 0
                    ? "ar://a"
                    : "https://example.org/full/entropy/finding/with/a/non-word-aligned-tail"
            );
            p.attestations[i].nonce = i + 1700;
        }
    }
}
