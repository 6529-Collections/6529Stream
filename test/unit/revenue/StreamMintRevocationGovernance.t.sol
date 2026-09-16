// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/MintRevocationTestBase.sol";
import "../../helpers/StreamGovernanceBootstrapHarness.sol";

/// @dev Actual sealed Executor and RoleRegistry, with bootstrap inventory/Core doubles explicit.
contract StreamMintRevocationGovernanceTest is StreamGovernanceBootstrapHarness {
    StreamMintManager private manager;
    BootstrapArtifacts private bootstrap;

    function _additionalActionPolicies(BootstrapArtifacts memory a)
        internal
        override
        returns (GovernanceActionPolicyEntry[] memory entries)
    {
        StreamModuleRegistry registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(a.executor)),
            keccak256("revocation registry"),
            "ipfs://registry"
        );
        MintRevocationCoreMock core = new MintRevocationCoreMock();
        core.initialize(address(registry), address(0), address(0));
        StreamMintLedger ledger = new StreamMintLedger();
        manager = new StreamMintManager(
            IStreamCore(address(core)),
            IStreamMintLedger(address(ledger)),
            IERC165(address(registry))
        );
        entries = new GovernanceActionPolicyEntry[](3);
        for (uint8 i; i < 3; i++) {
            entries[i] = _zeroPolicy(
                i,
                address(manager),
                IStreamGasParameterHost.raiseGasParameter.selector,
                keccak256("revocation manager")
            );
        }
    }

    function currentTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function setUp() public {
        vm.warp(1000);
        bootstrap = _deploySealedExecutor(address(this));
    }

    function _action(bytes32 id, uint256 next)
        private
        view
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        (uint256 value, uint256 floor, uint8 failure, uint64 rev) = manager.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(manager),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        data = new bytes[](1);
        data[0] = abi.encodeCall(manager.raiseGasParameter, (id, next));
        calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall(
            address(manager),
            0,
            IStreamGasParameterHost.raiseGasParameter.selector,
            keccak256(data[0]),
            scope,
            keccak256(abi.encode(domain, scope, value, floor, failure, rev)),
            keccak256(abi.encode(domain, scope, next, floor, failure, rev + 1))
        );
    }

    function _hashes(GovernanceCall[] memory calls)
        private
        pure
        returns (bytes32, bytes32, bytes32)
    {
        bytes32 callsHash = keccak256(abi.encode(GOVERNANCE_CALLS_V2, calls));
        bytes32[] memory scopes = new bytes32[](1);
        scopes[0] = calls[0].scopeHash;
        bytes32[] memory oldValues = new bytes32[](1);
        oldValues[0] = calls[0].oldValueHash;
        bytes32[] memory newValues = new bytes32[](1);
        newValues[0] = calls[0].newValueHash;
        return (
            keccak256(abi.encode(BATCH_SCOPE_V2, callsHash, scopes)),
            keccak256(abi.encode(BATCH_OLD_STATE_V2, callsHash, oldValues)),
            keccak256(abi.encode(BATCH_NEW_STATE_V2, callsHash, newValues))
        );
    }

    function _schedule(uint8 cls, GovernanceCall[] memory calls, bytes[] memory data, uint64 at)
        private
        returns (bytes32)
    {
        bootstrap.executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _hashes(calls);
        return bootstrap.executor
            .scheduleGovernanceBatch(
                cls,
                calls,
                scope,
                oldState,
                newState,
                at,
                at + 7 days,
                keccak256(abi.encode("revocation cap", cls)),
                "ipfs://revocation-cap",
                bootstrap.manifestHash
            );
    }

    function scheduleForTest(
        uint8 cls,
        GovernanceCall[] calldata calls,
        bytes[] calldata data,
        uint64 at
    ) external {
        require(msg.sender == address(this), "test only");
        _schedule(cls, calls, data, at);
    }

    function testActualDelayedClassOneRaisesNewAndExistingRowsOnlyAfter48Hours() public {
        require(bootstrap.executor.minimumDelay(1) == 48 hours, "canonical delay");
        bytes32[2] memory ids = [
            manager.GGP_MINT_REVOCATION_ERC1271_GAS_LIMIT(),
            manager.GGP_ARTIST_AUTHORITY_GAS_LIMIT()
        ];
        for (uint256 i; i < 2; i++) {
            uint256 old = manager.gasParameter(ids[i]);
            (GovernanceCall[] memory calls, bytes[] memory data) = _action(ids[i], old * 2);
            uint64 at = uint64(this.currentTimestamp() + 48 hours);
            bytes32 actionId = _schedule(1, calls, data, at);
            vm.warp(at - 1);
            (bool early,) = address(bootstrap.executor)
                .call(
                    abi.encodeCall(
                        bootstrap.executor.executeGovernanceBatch, (actionId, calls, data)
                    )
                );
            require(!early && manager.gasParameter(ids[i]) == old, "too early atomic");
            vm.warp(at);
            bootstrap.executor.executeGovernanceBatch(actionId, calls, data);
            (uint256 value,, uint8 failure, uint64 revision) = manager.gasParameterInfo(ids[i]);
            require(
                value == old * 2 && failure == 2 && revision == 2, "same class distinct failure"
            );
        }
    }

    function testActualWrongClassesCannotRaiseEitherRow() public {
        bytes32[2] memory ids = [
            manager.GGP_MINT_REVOCATION_ERC1271_GAS_LIMIT(),
            manager.GGP_ARTIST_AUTHORITY_GAS_LIMIT()
        ];
        for (uint256 i; i < 2; i++) {
            for (uint8 j; j < 2; j++) {
                uint8 cls = j == 0 ? 0 : 2;
                uint256 old = manager.gasParameter(ids[i]);
                (GovernanceCall[] memory calls, bytes[] memory data) = _action(ids[i], old * 2);
                uint64 at = uint64(this.currentTimestamp() + bootstrap.executor.minimumDelay(cls));
                if (cls == 0) {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IStreamGovernanceExecutor.NotClassifiedTightening.selector,
                            address(manager),
                            IStreamGasParameterHost.raiseGasParameter.selector
                        )
                    );
                    this.scheduleForTest(cls, calls, data, at);
                    require(manager.gasParameter(ids[i]) == old, "Executor rejects class0");
                    continue;
                }
                bytes32 actionId = _schedule(cls, calls, data, at);
                vm.warp(at);
                (bool ok, bytes memory reason) = address(bootstrap.executor)
                    .call(
                        abi.encodeCall(
                            bootstrap.executor.executeGovernanceBatch, (actionId, calls, data)
                        )
                    );
                require(!ok && manager.gasParameter(ids[i]) == old, "wrong class rollback");
                // Executor wraps the target's exact error; locate its fixed 68-byte payload suffix.
                bytes memory expected = abi.encodeWithSelector(
                    IStreamGasParameterHost.GasParameterActionClassMismatch.selector, uint8(1), cls
                );
                bool found;
                for (uint256 k; k + expected.length <= reason.length; k++) {
                    bool equal = true;
                    for (uint256 n; n < expected.length; n++) {
                        if (reason[k + n] != expected[n]) {
                            equal = false;
                            break;
                        }
                    }
                    if (equal) {
                        found = true;
                        break;
                    }
                }
                require(found, "exact target class mismatch");
            }
        }
    }
}
