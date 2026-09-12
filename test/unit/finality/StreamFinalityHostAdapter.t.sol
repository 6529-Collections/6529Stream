// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalityHostAdapter.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

/// @dev Explicit boundary double; no claim that these facts establish actual artwork readiness.
contract FinalityHostBoundary {
    address public core;
    uint256 public malformed;
    bool public frozen = true;
    bool public invalidMarker;
    bool public missingFacts;

    constructor(address core_) {
        core = core_;
    }

    function setCore(address value) external {
        core = value;
    }

    function setMalformed(uint256 value) external {
        malformed = value;
    }

    function setFrozen(bool value) external {
        frozen = value;
    }

    function setInvalidMarker(bool value) external {
        invalidMarker = value;
    }

    function setMissingFacts(bool value) external {
        missingFacts = value;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        if (id == 0xffffffff) return invalidMarker;
        return id == 0x01ffc9a7 || id == type(IStreamFinalityComponentFacts).interfaceId
            || id == type(IStreamCollectionMetadata).interfaceId
            || id == type(IStreamMetadataRouter).interfaceId
            || id == type(IStreamEntropyCoordinator).interfaceId;
    }

    function finalityComponentFacts(bytes32 family, StreamFinalityScope memory scope)
        external
        view
        returns (StreamFinalityHostComponentFacts memory)
    {
        if (malformed == 1) assembly { return(0, 0) }
        if (malformed == 2) assembly { return(0, 160) }
        if (malformed == 3) {
            assembly {
                mstore(0, 2)
                return(0, 128)
            }
        }
        if (malformed == 4) revert("host read failed");
        if (malformed == 5) {
            bytes memory oversized = new bytes(65536);
            assembly { return(add(oversized, 32), mload(oversized)) }
        }
        return StreamFinalityHostComponentFacts(
            frozen,
            keccak256("version"),
            keccak256(abi.encode(family, scope)),
            missingFacts ? bytes32(0) : keccak256("actual-host-data")
        );
    }
}

contract FinalityPointerBoundary {
    StreamFinalityHostAdapter.PointerFacts private _pointer;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function setPointer(StreamFinalityHostAdapter.PointerFacts memory facts) external {
        _pointer = facts;
    }

    function getSatellitePointer(bytes32)
        external
        view
        returns (StreamFinalityHostAdapter.PointerFacts memory)
    {
        return _pointer;
    }
}

contract StreamFinalityHostAdapterTest is CharacterizationTestBase, OfficialSafeFixture {
    FinalityPointerBoundary private source = new FinalityPointerBoundary();
    FinalityHostBoundary private producer = new FinalityHostBoundary(address(source));

    function testEveryFamilyUsesExactHostPointerAndOwnComponentIdentity() public {
        bytes32[9] memory families = [
            keccak256("COLLECTION_METADATA"),
            keccak256("REFERENCE_RENDER"),
            keccak256("ENTROPY_COORDINATOR"),
            keccak256("METADATA_ROUTER"),
            keccak256("RENDERER"),
            keccak256("RENDER_CONTEXT"),
            keccak256("MEDIA_MANIFEST"),
            keccak256("SCRIPT_SOURCE"),
            keccak256("DEPENDENCY_SOURCE")
        ];
        for (uint256 i; i < families.length; ++i) {
            StreamFinalityHostAdapter adapter =
                new StreamFinalityHostAdapter(address(source), address(producer), families[i]);
            StreamFinalityComponentState memory facts = adapter.finalityState(7);
            require(
                facts.componentType == families[i] && facts.component == address(adapter),
                "adapter identity"
            );
            require(
                facts.codeHash == address(adapter).codehash
                    && facts.interfaceId == type(IStreamFinalityHostAdapter).interfaceId,
                "identity proof"
            );
            bytes32 expected = i < 2
                ? keccak256("COLLECTION_METADATA")
                : i == 2 ? keccak256("ENTROPY_COORDINATOR") : keccak256("METADATA_ROUTER");
            require(adapter.hostPointerType() == expected, "wrong family pointer");
            source.setPointer(_pointer(adapter));
            adapter.requireCurrentSelection();
        }
    }

    function testHistoricalReadsSurviveReplacementButNewDiscoveryRejects() public {
        StreamFinalityHostAdapter adapter = _adapter();
        bytes32 original = keccak256(abi.encode(adapter.finalityState(7)));
        StreamFinalityHostAdapter.PointerFacts memory pointer = _pointer(adapter);
        pointer.target = address(0x123);
        source.setPointer(pointer);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityHostAdapter.FinalityHostNotSelected.selector, pointer.target
            )
        );
        adapter.requireCurrentSelection();
        require(
            keccak256(abi.encode(adapter.finalityState(7))) == original,
            "history depends on current pointer"
        );
    }

    function testEveryRecordedPointerCommitmentIsChecked() public {
        StreamFinalityHostAdapter adapter = _adapter();
        for (uint256 i; i < 8; ++i) {
            StreamFinalityHostAdapter.PointerFacts memory p = _pointer(adapter);
            if (i == 0) p.codeHash = bytes32(uint256(1));
            if (i == 1) p.moduleType = keccak256("OTHER");
            if (i == 2) p.interfaceId = 0xffffffff;
            if (i == 3) p.registry = address(0);
            if (i == 4) p.registryStatus = 2;
            if (i == 5) p.moduleManifestHash = 0;
            if (i == 6) p.deploymentManifestHash = 0;
            if (i == 7) p.revision = 0;
            source.setPointer(p);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamFinalityHostAdapter.FinalityHostNotSelected.selector, address(producer)
                )
            );
            adapter.requireCurrentSelection();
        }
    }

    function testLiveReciprocalIdentityAndCodePinsCannotDrift() public {
        StreamFinalityHostAdapter adapter = _adapter();
        producer.setCore(address(0x123));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityHostAdapter.InvalidFinalityHost.selector, address(producer)
            )
        );
        adapter.finalityState(7);
        producer.setCore(address(source));
        producer.setInvalidMarker(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityHostAdapter.InvalidFinalityHost.selector, address(producer)
            )
        );
        adapter.finalityState(7);
        producer.setInvalidMarker(false);
        bytes memory code = address(producer).code;
        vm.etch(address(producer), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityHostAdapter.InvalidFinalityHost.selector, address(producer)
            )
        );
        adapter.finalityState(7);
        vm.etch(address(producer), code);
        vm.etch(address(source), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityHostAdapter.InvalidFinalityCore.selector, address(source)
            )
        );
        adapter.finalityState(7);
    }

    function testMalformedAndOversizedFactsFailWithoutBecomingReady() public {
        StreamFinalityHostAdapter adapter = _adapter();
        for (uint256 i = 1; i <= 5; ++i) {
            producer.setMalformed(i);
            vm.expectRevert();
            adapter.finalityState(7);
        }
        producer.setMalformed(0);
        producer.setFrozen(false);
        require(!adapter.finalityState(7).frozen, "false readiness changed");
        producer.setMissingFacts(true);
        vm.expectRevert(
            abi.encodeWithSelector(StreamFinalityHostAdapter.InvalidFinalityHostFacts.selector)
        );
        adapter.finalityState(7);
    }

    function testUnknownFamilyAndWrongConstructorBindingsReject() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityHostAdapter.UnknownFinalityComponent.selector, keccak256("UNKNOWN")
            )
        );
        new StreamFinalityHostAdapter(address(source), address(producer), keccak256("UNKNOWN"));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityHostAdapter.InvalidFinalityCore.selector, address(0)
            )
        );
        new StreamFinalityHostAdapter(address(0), address(producer), keccak256("RENDERER"));
        producer.setCore(address(0x123));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityHostAdapter.InvalidFinalityHost.selector, address(producer)
            )
        );
        new StreamFinalityHostAdapter(
            address(source), address(producer), keccak256("COLLECTION_METADATA")
        );
    }

    function testScopedReadsPreserveScopeAndRejectAliases() public {
        StreamFinalityHostAdapter adapter = _adapter();
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        require(
            keccak256(abi.encode(adapter.finalityState(7)))
                == keccak256(abi.encode(adapter.finalityStateForScope(scope))),
            "collection alias"
        );
        bytes32 collectionManifest = adapter.finalityState(7).manifestHash;
        scope.scopeType = StreamFinalityScopeType.TOKEN;
        scope.tokenId = 19;
        require(
            adapter.finalityStateForScope(scope).manifestHash != collectionManifest,
            "scope discarded"
        );
        scope.scopeId = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataSubjects.InvalidMetadataScope.selector)
        );
        adapter.finalityStateForScope(scope);
    }

    function testOfficialSafeCanCallEveryPublicReadAndObserveRejection() public {
        StreamFinalityHostAdapter adapter = _adapter();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x652901;
        keys[1] = 0x652902;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 6529);
        bytes[] memory calls = new bytes[](11);
        calls[0] = abi.encodeCall(IStreamFinalityHostAdapter.core, ());
        calls[1] = abi.encodeCall(IStreamFinalityHostAdapter.host, ());
        calls[2] = abi.encodeCall(IStreamFinalityHostAdapter.componentType, ());
        calls[3] = abi.encodeCall(IStreamFinalityHostAdapter.hostCodeHash, ());
        calls[4] = abi.encodeCall(IStreamFinalityHostAdapter.coreCodeHash, ());
        calls[5] = abi.encodeCall(IStreamFinalityHostAdapter.hostPointerType, ());
        calls[6] = abi.encodeWithSignature("hostInterfaceId()");
        calls[7] = abi.encodeCall(
            IERC165.supportsInterface, (type(IStreamFinalityHostAdapter).interfaceId)
        );
        calls[8] = abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (7));
        calls[9] = abi.encodeCall(
            IStreamArtworkScopedFinalityComponent.finalityStateForScope,
            (StreamFinalityScope(StreamFinalityScopeType.TOKEN, 7, 19, 0))
        );
        calls[10] = abi.encodeCall(IStreamFinalityHostAdapter.requireCurrentSelection, ());
        for (uint256 i; i < calls.length; ++i) {
            require(executeSafe(account, keys, address(adapter), 0, calls[i], 0), "Safe read");
        }
        source.setPointer(
            StreamFinalityHostAdapter.PointerFacts(
                address(0), 0, false, 0, 0, address(0), 0, 0, 0, 0
            )
        );
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(adapter), 0, calls[10], 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(adapter), 0, calls[10], 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == nonce, "failed Safe consumed nonce");
    }

    function _adapter() private returns (StreamFinalityHostAdapter adapter) {
        adapter = new StreamFinalityHostAdapter(
            address(source), address(producer), keccak256("COLLECTION_METADATA")
        );
        source.setPointer(_pointer(adapter));
    }

    function _pointer(StreamFinalityHostAdapter adapter)
        private
        view
        returns (StreamFinalityHostAdapter.PointerFacts memory)
    {
        return StreamFinalityHostAdapter.PointerFacts(
            address(producer),
            address(producer).codehash,
            false,
            adapter.hostPointerType(),
            adapter.hostInterfaceId(),
            address(0x6529),
            1,
            keccak256("module"),
            keccak256("deployment"),
            1
        );
    }
}
