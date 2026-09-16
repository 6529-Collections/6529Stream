// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/metadata/StreamRecordSelectionLocks.sol";

interface RecordSelectionLockVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

/// @dev Explicit ModuleRegistry response boundary for actual selector tests.
contract RecordSelectionModuleBoundary {
    address public immutable governanceExecutor;

    constructor(address executor) {
        governanceExecutor = executor;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamModuleRegistry).interfaceId || id == 0x01ffc9a7;
    }
}

/// @dev Actual selection/storage/Safe tests use explicitly supplied canonical governance reads.
/// Delayed scheduling, global veto and the same guard against a real Executor are separate tests.
abstract contract RecordSelectionLockFixture {
    RecordSelectionLockVm internal constant sealVm =
        RecordSelectionLockVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _sealGraph(address core, address executor) internal returns (address registry) {
        registry = address(new RecordSelectionModuleBoundary(executor));
        _sealPointer(core, registry, executor, 1);
    }

    function _sealPointer(address core, address registry, address executor, uint64 revision)
        internal
    {
        sealVm.mockCall(
            core,
            abi.encodeWithSignature("getSatellitePointer(bytes32)", keccak256("MODULE_REGISTRY")),
            abi.encode(
                registry,
                registry.codehash,
                false,
                keccak256("MODULE_REGISTRY"),
                type(IStreamModuleRegistry).interfaceId,
                registry,
                uint8(1),
                keccak256("fixture registry manifest"),
                keccak256("fixture registry deployment"),
                revision
            )
        );
        (address root,,) = IStreamGovernanceReads(executor).governanceRootState();
        sealVm.mockCall(executor, abi.encodeWithSignature("owner()"), abi.encode(root));
    }

    function _sealWitness(
        address executor,
        uint8 activeClass,
        uint8 storedClass,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) internal returns (bytes32 actionId) {
        actionId = keccak256(
            abi.encode("explicit selection seal action fixture", executor, scope, oldHash, newHash)
        );
        sealVm.mockCall(
            executor,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, actionId, activeClass, scope, oldHash, newHash)
        );
        GovernanceAction memory a;
        a.status = GovernanceActionStatus.EXECUTED;
        a.actionClass = storedClass;
        a.target = address(0x1234); // First batch call differs; the active call above is exact.
        a.selector = 0x11223344;
        (a.proposer,,) = IStreamGovernanceReads(executor).governanceRootState();
        a.reasonURI = "urn:fixture:selection-seal";
        a.reasonHash = keccak256(bytes(a.reasonURI));
        sealVm.mockCall(
            executor,
            abi.encodeCall(IStreamGovernanceReads.governanceAction, (actionId)),
            abi.encode(a)
        );
    }

    function _sealClear() internal {
        sealVm.clearMockedCalls();
    }
}
