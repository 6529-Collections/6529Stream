// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SaleFundingTestMocks.sol";
import "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

/// @dev Pointer and token-identity seam, not the actual Core governance implementation.
contract UniversalCoreMock {
    address public artists;
    address public registry;

    function configure(address a, address r) external {
        artists = a;
        registry = r;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address target = kind == keccak256("ARTIST_REGISTRY") ? artists : registry;
        bytes4 capability = kind == keccak256("ARTIST_REGISTRY")
            ? type(IStreamArtistAttribution).interfaceId
            : type(IStreamModuleRegistry).interfaceId;
        return (
            target,
            target.codehash,
            false,
            kind,
            capability,
            registry,
            1,
            keccak256("manifest"),
            keccak256("deployment"),
            1
        );
    }
}

/// @dev Only the manager identity, preview and receiver seam. Real ledger/Core composition
///      is an integration test; all payment, registry, wallet and permit contracts are real.
contract UniversalManagerMock is SaleFundingManagerMock {
    address public immutable moduleRegistry;

    constructor(address c, address r) SaleFundingManagerMock(c) {
        moduleRegistry = r;
    }

    function isStreamMintManager() external pure returns (bool) {
        return true;
    }
}

/// @dev Exact token with independent EIP-2612 signature verification and recipient-local faults.
contract UniversalPermitToken {
    mapping(address => uint256) private _balances;
    bool public balanceFailure;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;
    address public faultRecipient;
    uint8 public mode;
    bool public preserveMax;
    address public callback;
    bytes public callbackData;
    bool public callbackSuccess;
    bytes32 public callbackResultHash;
    uint256 public permitGas;

    function setBalanceFailure(bool failed) external {
        balanceFailure = failed;
    }

    function balanceOf(address who) external view returns (uint256) {
        require(!balanceFailure, "balance read failed");
        return _balances[who];
    }

    function mint(address who, uint256 amount) external {
        _balances[who] += amount;
    }

    function configure(address who, uint8 fault) external {
        faultRecipient = who;
        mode = fault;
    }

    function setPreserveMax(bool value) external {
        preserveMax = value;
    }

    function setCallback(address target, bytes calldata data) external {
        callback = target;
        callbackData = data;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 approval = allowance[from][msg.sender];
        if (!(preserveMax && approval == type(uint256).max)) {
            allowance[from][msg.sender] = approval - amount;
        }
        return _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) private returns (bool) {
        uint8 fault = to == faultRecipient ? mode : 0;
        if (fault == 1) revert("wallet refused");
        if (fault == 3) return true;
        _balances[from] -= amount;
        _balances[to] += fault == 4 ? amount - 1 : amount;
        if (callback != address(0)) {
            bytes memory data;
            (callbackSuccess, data) = callback.call(callbackData);
            callbackResultHash = keccak256(data);
        }
        if (fault == 2) return false;
        if (fault == 5) assembly ("memory-safe") { return(0, 0) }
        if (fault == 6) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(0, 64)
            }
        }
        if (fault == 7) assembly ("memory-safe") { for { } 1 { } { } }
        if (fault == 8) assembly ("memory-safe") { revert(mload(0x40), 65536) }
        return true;
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("UniversalPermitToken"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function permitDigest(address owner, address spender, uint256 amount, uint256 deadline)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        owner,
                        spender,
                        amount,
                        nonces[owner],
                        deadline
                    )
                )
            )
        );
    }

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        permitGas = gasleft();
        require(
            block.timestamp <= deadline && owner != address(0) && (v == 27 || v == 28),
            "permit terms"
        );
        require(
            uint256(s) <= 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0
                && ecrecover(permitDigest(owner, spender, amount, deadline), v, r, s) == owner,
            "permit signature"
        );
        ++nonces[owner];
        allowance[owner][spender] = amount;
    }
}
