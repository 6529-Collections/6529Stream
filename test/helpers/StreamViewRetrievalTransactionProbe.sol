// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Exact relevant ABI, Foundry 1.7.1 / 4072e48705af9d93e3c0f6e29e93b5e9a40caed8.
interface ViewRetrievalTransactionVm {
    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8, bytes32, bytes32);
    function getNonce(address) external view returns (uint64);
    function executeTransaction(bytes calldata rawTx) external returns (bytes memory);
    function snapshotState() external returns (uint256);
    function revertToState(uint256) external returns (bool);
}

/// @notice Test-only signed EIP-155 transactions against the genuine fixture state.
/// @dev No allocations/code/slots are installed. The pinned VM starts a fresh nested EVM,
/// with normal transaction warmth and intrinsic gas. Zero gas price is test-only; this
/// asserts a gas ceiling, not an RPC receipt or a fee observation. The public test key
/// is deliberately derived from a literal and must never hold assets outside tests.
library StreamViewRetrievalTransactionProbe {
    ViewRetrievalTransactionVm private constant VM =
        ViewRetrievalTransactionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant TRANSACTION_LIMIT = 16777216;
    uint256 private constant KEY =
        uint256(keccak256("6529STREAM_PUBLIC_TEST_VIEW_RETRIEVAL_RELAYER"));

    struct Result {
        address sender;
        uint64 nonce;
        uint256 gasLimit;
        uint256 intrinsic;
        bytes32 signedTransactionHash;
        bytes32 inputHash;
        bytes32 outputHash;
    }
    event RetrievalTransactionBound(address indexed target, bytes4 indexed selector, Result result);

    function execute(address target, bytes memory input, uint256 gasLimit)
        public
        returns (bytes memory output, Result memory result)
    {
        require(
            target != address(0) && gasLimit <= TRANSACTION_LIMIT, "original transaction ceiling"
        );
        result.intrinsic = intrinsicGas(input);
        require(gasLimit > result.intrinsic, "positive execution allowance");
        result.sender = VM.addr(KEY);
        result.nonce = VM.getNonce(result.sender);
        result.gasLimit = gasLimit;
        result.inputHash = keccak256(input);
        bytes memory head = bytes.concat(
            _integer(result.nonce),
            hex"80",
            _integer(gasLimit),
            _bytes(abi.encodePacked(target)),
            hex"80",
            _bytes(input)
        );
        bytes memory unsigned = _list(bytes.concat(head, _integer(block.chainid), hex"8080"));
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(KEY, keccak256(unsigned));
        bytes memory signed = _list(
            bytes.concat(
                head,
                _integer(block.chainid * 2 + 35 + v - 27),
                _integer(uint256(r)),
                _integer(uint256(s))
            )
        );
        result.signedTransactionHash = keccak256(signed);
        output = VM.executeTransaction(signed);
        require(VM.getNonce(result.sender) == result.nonce + 1, "exact real transaction nonce");
        result.outputHash = keccak256(output);
        emit RetrievalTransactionBound(target, bytes4(input), result);
    }

    function intrinsicGas(bytes memory input) public pure returns (uint256 total) {
        total = 21000;
        for (uint256 i; i < input.length; ++i) {
            total += input[i] == 0 ? 4 : 16;
        }
    }

    function _integer(uint256 value) private pure returns (bytes memory) {
        if (value == 0) return hex"80";
        uint256 length;
        for (uint256 n = value; n != 0; n >>= 8) {
            ++length;
        }
        bytes memory raw = new bytes(length);
        for (uint256 i; i < length; ++i) {
            raw[length - 1 - i] = bytes1(uint8(value >> (i * 8)));
        }
        return _bytes(raw);
    }

    function _bytes(bytes memory raw) private pure returns (bytes memory) {
        if (raw.length == 1 && uint8(raw[0]) < 128) return raw;
        if (raw.length <= 55) return bytes.concat(bytes1(uint8(128 + raw.length)), raw);
        return bytes.concat(_length(raw.length, 183), raw);
    }

    function _list(bytes memory raw) private pure returns (bytes memory) {
        if (raw.length <= 55) return bytes.concat(bytes1(uint8(192 + raw.length)), raw);
        return bytes.concat(_length(raw.length, 247), raw);
    }

    function _length(uint256 n, uint256 offset) private pure returns (bytes memory) {
        uint256 length;
        for (uint256 value = n; value != 0; value >>= 8) {
            ++length;
        }
        bytes memory prefix = new bytes(length + 1);
        prefix[0] = bytes1(uint8(offset + length));
        for (uint256 i; i < length; ++i) {
            prefix[length - i] = bytes1(uint8(n >> (i * 8)));
        }
        return prefix;
    }
}
