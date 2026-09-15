// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../script/current/StreamDeploymentSlot.sol";
import "../helpers/OfficialSafeFixture.sol";

interface DeploymentSlotVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
    function prank(address sender) external;
    function expectRevert(bytes4 selector) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract DeploymentSlotGate {
    bool public ready;
    uint256 public observations;

    function setReady(bool value) external {
        ready = value;
    }

    function observe() external {
        require(ready, "constructor dependency unavailable");
        ++observations;
    }
}

contract DeploymentSlotProduct {
    uint256 public value;
    address public authority;
    address public constructorCaller;

    constructor(uint256 value_, address authority_, DeploymentSlotGate gate) {
        gate.observe();
        value = value_;
        authority = authority_;
        constructorCaller = msg.sender;
    }
}

contract DeploymentSlotOversizedProduct {
    constructor() {
        bytes memory runtime = new bytes(24_577);
        assembly ("memory-safe") { return(add(runtime, 32), mload(runtime)) }
    }
}

contract DeploymentSlotReentrantOperator {
    StreamDeploymentSlot public slot;
    bool public rejected;

    function setSlot(StreamDeploymentSlot value) external {
        require(address(slot) == address(0));
        slot = value;
    }

    function deploy(bytes memory code, bytes32 runtime) external {
        slot.deploy(code, runtime);
    }

    function callback() external {
        (bool ok, bytes memory result) =
            address(slot).call(abi.encodeCall(slot.deploy, (hex"00", bytes32(uint256(1)))));
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(StreamDeploymentSlot.SlotConsumed.selector)
                    ),
            "reentry must reject consumed slot"
        );
        rejected = true;
    }
}

contract DeploymentSlotReentrantProduct {
    constructor(DeploymentSlotReentrantOperator owner) {
        owner.callback();
    }
}

contract StreamDeploymentSlotTest is OfficialSafeFixture {
    DeploymentSlotVm private constant slotVm =
        DeploymentSlotVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _code(uint256 value, address authority, DeploymentSlotGate gate)
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            type(DeploymentSlotProduct).creationCode, abi.encode(value, authority, gate)
        );
    }

    function _runtime() private pure returns (bytes32) {
        return keccak256(type(DeploymentSlotProduct).runtimeCode);
    }

    function _unused(StreamDeploymentSlot slot) private view {
        require(
            !slot.consumed() && slot.product().code.length == 0
                && slotVm.getNonce(address(slot)) == 1,
            "failed deployment fully rolled back"
        );
    }

    function _gate() private returns (DeploymentSlotGate gate) {
        gate = new DeploymentSlotGate();
        gate.setReady(true);
    }

    function testReservedCoordinateIgnoresLaterOperatorCreationsAndBindsExactEvent() public {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(this));
        address reserved = slot.product();
        require(
            reserved == slotVm.computeCreateAddress(address(slot), 1), "independent CREATE oracle"
        );
        DeploymentSlotGate gate = _gate();
        new DeploymentSlotGate();
        bytes memory code = _code(6529, address(0xA47157), gate);
        slotVm.recordLogs();
        address actual = slot.deploy(code, _runtime());
        DeploymentSlotVm.Log[] memory logs = slotVm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(slot), "one deployment event");
        require(
            logs[0].topics.length == 3
                && logs[0].topics[0] == keccak256("ProductDeployed(address,bytes32,bytes32)")
                && logs[0].topics[1] == bytes32(uint256(uint160(reserved)))
                && logs[0].topics[2] == keccak256(code)
                && keccak256(logs[0].data) == keccak256(abi.encode(_runtime())),
            "exact event commitments"
        );
        require(
            actual == reserved && slot.consumed() && slotVm.getNonce(address(slot)) == 2,
            "one real CREATE"
        );
        DeploymentSlotProduct p = DeploymentSlotProduct(actual);
        require(
            p.value() == 6529 && p.authority() == address(0xA47157)
                && p.constructorCaller() == address(slot),
            "explicit authority and constructor sender"
        );
        slotVm.expectRevert(StreamDeploymentSlot.SlotConsumed.selector);
        slot.deploy(code, _runtime());
    }

    function testOnlyConfiguredOperatorCanConsumeCoordinate() public {
        slotVm.expectRevert(StreamDeploymentSlot.InvalidOperator.selector);
        new StreamDeploymentSlot(address(0));
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(this));
        bytes memory code = _code(1, address(this), _gate());
        slotVm.prank(address(0xBAD));
        slotVm.expectRevert(StreamDeploymentSlot.OperatorRequired.selector);
        slot.deploy(code, _runtime());
        _unused(slot);
        require(slot.operator() == address(this), "operator immutable");
        slot.deploy(code, _runtime());
    }

    function testCreationAndRuntimeCommitmentBoundsDoNotConsumeCoordinate() public {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(this));
        slotVm.expectRevert(StreamDeploymentSlot.InvalidCreationCode.selector);
        slot.deploy(bytes(""), _runtime());
        slotVm.expectRevert(StreamDeploymentSlot.InvalidCreationCode.selector);
        slot.deploy(new bytes(49_153), _runtime());
        slotVm.expectRevert(StreamDeploymentSlot.InvalidRuntimeCommitment.selector);
        slot.deploy(hex"00", bytes32(0));
        _unused(slot);
    }

    function testConstructorFailureAllowsIdenticalCreationRetry() public {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(this));
        DeploymentSlotGate gate = new DeploymentSlotGate();
        bytes memory code = _code(7, address(this), gate);
        slotVm.expectRevert(StreamDeploymentSlot.DeploymentFailed.selector);
        slot.deploy(code, _runtime());
        _unused(slot);
        require(gate.observations() == 0, "no failed constructor effects");
        gate.setReady(true);
        slot.deploy(code, _runtime());
        require(
            gate.observations() == 1 && DeploymentSlotProduct(slot.product()).value() == 7,
            "same bytes retry"
        );
    }

    function testRuntimeMismatchRollsBackConstructorEffectsAndCreateNonce() public {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(this));
        DeploymentSlotGate gate = _gate();
        bytes memory code = _code(8, address(this), gate);
        (bool ok, bytes memory error) =
            address(slot).call(abi.encodeCall(slot.deploy, (code, bytes32(uint256(1)))));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamDeploymentSlot.RuntimeMismatch.selector,
                            _runtime(),
                            bytes32(uint256(1))
                        )
                    ),
            "exact runtime mismatch"
        );
        _unused(slot);
        require(
            gate.observations() == 0, "post-CREATE mismatch rolls back external constructor writes"
        );
        slot.deploy(code, _runtime());
        require(gate.observations() == 1, "single committed constructor");
    }

    function testEmptyRuntimeIsNotASuccessfulDeployment() public {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(this));
        (bool ok, bytes memory error) =
            address(slot).call(abi.encodeCall(slot.deploy, (hex"60006000f3", keccak256(bytes("")))));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamDeploymentSlot.InvalidRuntimeSize.selector, uint256(0)
                        )
                    ),
            "empty runtime rejected"
        );
        _unused(slot);
    }

    function testRuntimeLimitStillAppliesWithRaisedTestHarnessLimit() public {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(this));
        (bool ok, bytes memory error) = address(slot)
            .call(
                abi.encodeCall(
                    slot.deploy,
                    (
                        type(DeploymentSlotOversizedProduct).creationCode,
                        keccak256(new bytes(24_577))
                    )
                )
            );
        // The focused command raises the harness limit and exercises the helper's
        // explicit guard. An ordinary suite may reject the same CREATE at the EVM limit.
        bool helperRejected = keccak256(error)
            == keccak256(
                abi.encodeWithSelector(
                    StreamDeploymentSlot.InvalidRuntimeSize.selector, uint256(24_577)
                )
            );
        bool evmRejected = keccak256(error)
            == keccak256(abi.encodeWithSelector(StreamDeploymentSlot.DeploymentFailed.selector));
        require(!ok && (helperRejected || evmRejected), "product runtime limit enforced");
        _unused(slot);
    }

    function testAuthorizedConstructorReentryCannotConsumeAnotherCoordinate() public {
        DeploymentSlotReentrantOperator owner = new DeploymentSlotReentrantOperator();
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(owner));
        owner.setSlot(slot);
        owner.deploy(
            bytes.concat(type(DeploymentSlotReentrantProduct).creationCode, abi.encode(owner)),
            keccak256(type(DeploymentSlotReentrantProduct).runtimeCode)
        );
        require(
            owner.rejected() && slot.consumed() && slotVm.getNonce(address(slot)) == 2,
            "one product despite authorized callback"
        );
    }

    function testFuzzExactArgumentsAndAuthority(uint256 value, address authority) public {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(this));
        DeploymentSlotGate gate = _gate();
        slot.deploy(_code(value, authority, gate), _runtime());
        DeploymentSlotProduct product = DeploymentSlotProduct(slot.product());
        require(
            product.value() == value && product.authority() == authority
                && product.constructorCaller() == address(slot),
            "unaltered constructor arguments"
        );
    }

    function testActualSafeOwnsDeploymentAndIdenticalSignedFailureRetry() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529501;
        keys[1] = 0x6529502;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 6529);
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(safe));
        DeploymentSlotGate gate = new DeploymentSlotGate();
        bytes memory data =
            abi.encodeCall(slot.deploy, (_code(42, address(safe), gate), _runtime()));
        slotVm.prank(safeVm.addr(keys[0]));
        (bool ownerOk,) = address(slot).call(data);
        require(!ownerOk, "a Safe owner is not the Safe operator");
        bytes32 digest =
            safe.getTransactionHash(address(slot), 0, data, 0, 0, 0, 0, address(0), address(0), 0);
        bytes memory signatures = safeThresholdSignature(keys, digest);
        bytes memory transaction = abi.encodeCall(
            safe.execTransaction,
            (address(slot), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
        (bool first,) = address(safe).call(transaction);
        require(!first && safe.nonce() == 0, "failed Safe transaction rolls back nonce");
        _unused(slot);
        gate.setReady(true);
        (bool second, bytes memory result) = address(safe).call(transaction);
        require(
            second && keccak256(result) == keccak256(abi.encode(true)) && safe.nonce() == 1,
            "identical signed Safe retry succeeds once"
        );
        require(
            slot.consumed() && DeploymentSlotProduct(slot.product()).authority() == address(safe)
                && gate.observations() == 1,
            "actual Safe-owned product"
        );
    }
}
