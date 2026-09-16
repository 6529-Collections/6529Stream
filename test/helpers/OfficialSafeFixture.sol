// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface SafeFixtureVm {
    function readFile(string calldata path) external view returns (string memory);
    function parseJsonBytes(string calldata json, string calldata key)
        external
        pure
        returns (bytes memory);
    function addr(uint256 key) external returns (address);
    function sign(uint256 key, bytes32 digest) external returns (uint8, bytes32, bytes32);
    function cool(address target) external;
}

interface OfficialSafe {
    function setup(
        address[] calldata owners,
        uint256 threshold,
        address to,
        bytes calldata data,
        address handler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
    function nonce() external view returns (uint256);
    function VERSION() external view returns (string memory);
    function domainSeparator() external view returns (bytes32);
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce_
    ) external view returns (bytes32);
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
}

interface OfficialSafeFactory {
    function createProxyWithNonce(address singleton, bytes calldata initializer, uint256 saltNonce)
        external
        returns (address);
}

/// @notice Real upstream bytecode, real proxy setup and threshold signatures; no signer mock.
/// @dev Test keys are deterministic public fixtures. They must never fund real accounts.
abstract contract OfficialSafeFixture {
    SafeFixtureVm internal constant safeVm =
        SafeFixtureVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct SafeComponents {
        address singleton;
        address factory;
        address handler;
        address multiSend;
        address signMessage;
    }

    function deploySafeComponents(string memory version)
        internal
        returns (SafeComponents memory c)
    {
        string memory fixture = safeVm.readFile(
            string.concat("test/fixtures/safe/", version, ".json")
        );
        c.singleton = _deployArtifact(fixture, "singleton");
        c.factory = _deployArtifact(fixture, "factory");
        c.handler = _deployArtifact(fixture, "handler");
        c.multiSend = _deployArtifact(fixture, "multiSend");
        c.signMessage = _deployArtifact(fixture, "signMessage");
    }

    function createOfficialSafe(
        SafeComponents memory c,
        address[] memory owners,
        uint256 threshold,
        uint256 salt
    ) internal returns (OfficialSafe account) {
        bytes memory initializer = abi.encodeCall(
            OfficialSafe.setup,
            (
                owners,
                threshold,
                address(0),
                bytes(""),
                c.handler,
                address(0),
                0,
                payable(address(0))
            )
        );
        account = OfficialSafe(
            OfficialSafeFactory(c.factory).createProxyWithNonce(c.singleton, initializer, salt)
        );
        require(account.getThreshold() == threshold, "Safe setup threshold");
    }

    function safeOwnerAddresses(uint256[] memory keys) internal returns (address[] memory owners) {
        owners = new address[](keys.length);
        for (uint256 i; i < keys.length; ++i) {
            owners[i] = safeVm.addr(keys[i]);
        }
    }

    /// @dev Safe's handler wraps the Stream digest in SafeMessage(bytes), then its own EIP-712 domain.
    function safeMessageDigest(OfficialSafe account, bytes memory message)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                account.domainSeparator(),
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(message)))
            )
        );
    }

    function safeThresholdSignature(uint256[] memory keys, bytes32 digest)
        internal
        returns (bytes memory signatures)
    {
        // Sort a copy: callers retain their own key order.
        uint256[] memory sorted = new uint256[](keys.length);
        for (uint256 i; i < keys.length; ++i) {
            sorted[i] = keys[i];
            uint256 j = i;
            while (j > 0 && safeVm.addr(sorted[j - 1]) > safeVm.addr(sorted[j])) {
                (sorted[j - 1], sorted[j]) = (sorted[j], sorted[j - 1]);
                --j;
            }
        }
        for (uint256 i; i < sorted.length; ++i) {
            (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(sorted[i], digest);
            signatures = bytes.concat(signatures, abi.encodePacked(r, s, v));
        }
    }

    function executeSafe(
        OfficialSafe account,
        uint256[] memory keys,
        address target,
        uint256 value,
        bytes memory data,
        uint8 operation
    ) internal returns (bool) {
        uint256 transactionNonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            target, value, data, operation, 0, 0, 0, address(0), address(0), transactionNonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        return account.execTransaction(
            target, value, data, operation, 0, 0, 0, address(0), payable(address(0)), signatures
        );
    }

    function _deployArtifact(string memory fixture, string memory key)
        private
        returns (address target)
    {
        bytes memory creation =
            safeVm.parseJsonBytes(fixture, string.concat(".", key, ".creationCode"));
        bytes memory runtime =
            safeVm.parseJsonBytes(fixture, string.concat(".", key, ".runtimeCode"));
        assembly ("memory-safe") { target := create(0, add(creation, 32), mload(creation)) }
        require(
            target != address(0) && target.codehash == keccak256(runtime),
            "Official Safe bytecode mismatch"
        );
    }
}
