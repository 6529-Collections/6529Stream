// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewRetrievalTransactionProbe as Tx,
    ViewRetrievalTransactionVm as TxVm
} from "../../helpers/StreamViewRetrievalTransactionProbe.sol";

contract RetrievalTransactionLeaf {
    uint256 public value = 7;

    function echo(bytes calldata input) external view returns (bytes memory, address) {
        return (input, msg.sender);
    }

    function increment() external returns (uint256) {
        return ++value;
    }

    function price() external view returns (uint256 stored, uint256 used) {
        assembly ("memory-safe") {
            let beforeGas := gas()
            stored := sload(0)
            used := sub(beforeGas, gas())
        }
    }
}

contract RetrievalTransactionReader {
    function warmExceptions() external view returns (uint256 senderGas, uint256 precompileGas) {
        uint256 b;
        assembly ("memory-safe") {
            let beforeGas := gas()
            b := balance(caller())
            senderGas := sub(beforeGas, gas())
            beforeGas := gas()
            b := or(b, balance(1))
            precompileGas := sub(beforeGas, gas())
        }
        require(b == 0);
    }

    function price(address account)
        external
        view
        returns (
            address sender,
            address origin,
            uint256 accountGas,
            uint256 slotGas,
            uint256 value,
            uint256 destinationGas
        )
    {
        uint256 b;
        bytes32 h;
        assembly ("memory-safe") {
            let beforeGas := gas()
            b := balance(account)
            h := extcodehash(account)
            accountGas := sub(beforeGas, gas())
            beforeGas := gas()
            let selfHash := extcodehash(address())
            destinationGas := sub(beforeGas, gas())
            if iszero(selfHash) { revert(0, 0) }
        }
        require(b == 0 && h != 0);
        (value, slotGas) = RetrievalTransactionLeaf(account).price();
        return (msg.sender, tx.origin, accountGas, slotGas, value, destinationGas);
    }
}

contract RetrievalTransactionCallback {
    uint256 public count;
    address public lastSender;
    address public origin;

    function enter(address callback) external returns (uint256) {
        require(count == 0);
        ++count;
        lastSender = msg.sender;
        origin = tx.origin;
        return RetrievalTransactionRelay(callback).callback();
    }
}

contract RetrievalTransactionRelay {
    address public target;
    uint256 public callbacks;

    function run(address t) external returns (uint256) {
        target = t;
        return RetrievalTransactionCallback(t).enter(address(this));
    }

    function callback() external returns (uint256) {
        require(msg.sender == target && RetrievalTransactionCallback(target).count() == 1);
        return ++callbacks;
    }
}

contract StreamViewRetrievalTransactionProbeTest {
    TxVm private constant VM = TxVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    event ColdPrices(uint256 accountGas, uint256 slotGas, uint256 destinationGas);

    function testFreshTransactionUsesColdAccountSlotAndWarmDestination() external {
        RetrievalTransactionLeaf leaf = new RetrievalTransactionLeaf();
        RetrievalTransactionReader reader = new RetrievalTransactionReader();
        // Deliberately touch all relevant state before the fresh transaction.
        require(leaf.value() == 7 && address(leaf).code.length != 0);
        (bytes memory raw, Tx.Result memory result) =
            Tx.execute(address(reader), abi.encodeCall(reader.price, (address(leaf))), 100000);
        (
            address sender,
            address origin,
            uint256 accountGas,
            uint256 slotGas,
            uint256 value,
            uint256 destinationGas
        ) = abi.decode(raw, (address, address, uint256, uint256, uint256, uint256));
        emit ColdPrices(accountGas, slotGas, destinationGas);
        require(sender == result.sender && origin == result.sender && value == 7);
        require(accountGas >= 2700 && accountGas < 2750 && slotGas >= 2100 && slotGas < 2150);
        require(destinationGas >= 100 && destinationGas < 150);
        require(
            result.gasLimit == 100000
                && result.intrinsic
                    == Tx.intrinsicGas(abi.encodeCall(reader.price, (address(leaf))))
        );
    }

    function testFreshTransactionNonceMutationAndExactSnapshotRetry() external {
        RetrievalTransactionLeaf leaf = new RetrievalTransactionLeaf();
        uint256 snapshot = VM.snapshotState();
        (bytes memory first, Tx.Result memory a) =
            Tx.execute(address(leaf), abi.encodeCall(leaf.increment, ()), 100000);
        require(abi.decode(first, (uint256)) == 8 && leaf.value() == 8);
        require(VM.revertToState(snapshot) && leaf.value() == 7 && VM.getNonce(a.sender) == a.nonce);
        (bytes memory second, Tx.Result memory b) =
            Tx.execute(address(leaf), abi.encodeCall(leaf.increment, ()), 100000);
        require(
            keccak256(first) == keccak256(second)
                && a.signedTransactionHash == b.signedTransactionHash
        );
        require(leaf.value() == 8 && VM.getNonce(b.sender) == b.nonce + 1);
    }

    function testFreshTransactionPreservesActualCallbackAndOrigin() external {
        RetrievalTransactionCallback target = new RetrievalTransactionCallback();
        RetrievalTransactionRelay relay = new RetrievalTransactionRelay();
        (bytes memory raw, Tx.Result memory result) =
            Tx.execute(address(relay), abi.encodeCall(relay.run, (address(target))), 300000);
        require(abi.decode(raw, (uint256)) == 1 && target.count() == 1 && relay.callbacks() == 1);
        require(target.lastSender() == address(relay) && target.origin() == result.sender);
    }

    function testOriginalCeilingIntrinsicAndInsufficientTransactionRefuse() external {
        require(Tx.intrinsicGas(hex"0001ff00") == 21040);
        RetrievalTransactionLeaf leaf = new RetrievalTransactionLeaf();
        (bool ok,) =
            address(this).call(abi.encodeCall(this.execute, (address(leaf), uint256(16777217))));
        require(!ok && leaf.value() == 7);
        (ok,) = address(this).call(abi.encodeCall(this.execute, (address(leaf), uint256(21100))));
        require(!ok && leaf.value() == 7);
    }

    function testFreshTransactionPreservesSenderAndPrecompileWarmExceptions() external {
        RetrievalTransactionReader reader = new RetrievalTransactionReader();
        (bytes memory raw,) =
            Tx.execute(address(reader), abi.encodeCall(reader.warmExceptions, ()), 100000);
        (uint256 senderGas, uint256 precompileGas) = abi.decode(raw, (uint256, uint256));
        require(senderGas >= 100 && senderGas < 150 && precompileGas >= 100 && precompileGas < 150);
    }

    function testLongCompleteCalldataAndIntrinsicArePreserved() external {
        RetrievalTransactionLeaf leaf = new RetrievalTransactionLeaf();
        bytes memory value = new bytes(512);
        for (uint256 i; i < value.length; ++i) {
            value[i] = bytes1(uint8(i));
        }
        bytes memory input = abi.encodeCall(leaf.echo, (value));
        (bytes memory raw, Tx.Result memory result) = Tx.execute(address(leaf), input, 200000);
        (bytes memory actual, address sender) = abi.decode(raw, (bytes, address));
        require(
            actual.length == 512 && keccak256(actual) == keccak256(value) && sender == result.sender
        );
        require(result.inputHash == keccak256(input) && result.outputHash == keccak256(raw));
        require(
            result.intrinsic == Tx.intrinsicGas(input) && result.intrinsic > Tx.intrinsicGas(value)
        );
    }

    function execute(address leaf, uint256 limit) external {
        Tx.execute(leaf, abi.encodeCall(RetrievalTransactionLeaf.increment, ()), limit);
    }
}
