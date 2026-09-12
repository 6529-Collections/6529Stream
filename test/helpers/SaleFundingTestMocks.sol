// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamRevenueEscrow.sol";
import "../../smart-contracts/vendor/openzeppelin/IERC165.sol";
import "../../smart-contracts/vendor/openzeppelin/IERC721Receiver.sol";

interface SaleFundingFaultVm {
    function mockCallRevert(
        address callee,
        uint256 value,
        bytes calldata data,
        bytes calldata revertData
    ) external;
    function clearMockedCalls() external;
}

/// @dev Current artist read seam. Runtime authorization of the real facade remains integration evidence.
contract SaleFundingArtistMock is IStreamArtistAttribution, IERC165 {
    address public immutable override core;
    address public artist;
    bytes32 public nomination;
    bool public saleConsentRequired;
    uint256 public saleConsentFault;
    mapping(bytes32 => bool) public saleConsents;

    function configureSaleConsent(bool required, uint256 fault) external {
        saleConsentRequired = required;
        saleConsentFault = fault;
    }

    function recordTestSaleConsent(address adapter, uint256 collection, bytes32 id, bytes32 hash, bool allowed) external {
        saleConsents[keccak256(abi.encode(adapter, collection, id, hash))] = allowed;
    }

    /// @dev Domain seam only; canonical artist op16 record/authority proof belongs to integration.
    function requireSaleConsent(uint256 collection, bytes32 id, bytes32 hash) external view {
        require(nomination != 0, "binding absent");
        if (saleConsentFault == 1) revert("consent read failed");
        if (saleConsentFault == 2) { assembly ("memory-safe") { mstore(0, 1) return(0, 32) } }
        if (saleConsentFault == 3) { assembly ("memory-safe") { let p := mload(0x40) return(p, 65536) } }
        if (saleConsentRequired) require(saleConsents[keccak256(abi.encode(msg.sender, collection, id, hash))], "required consent absent");
    }

    constructor(address core_) {
        core = core_;
    }

    function accept(address value) external {
        artist = value;
        nomination = keccak256("binding");
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId || id == type(IERC165).interfaceId;
    }

    function acceptedArtist(uint256) external view returns (address) {
        return artist;
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        a.artist = artist;
        a.nominationHash = nomination;
        if (artist != address(0)) a.acceptanceHash = keccak256("acceptance");
    }
}

    /// @dev Only the manager identity/callback boundary. Does not claim Core, ledger or entropy execution.
    contract SaleFundingManagerMock {
        address public immutable core;
        bytes32 public constant POLICY = keccak256("funding manager policy");
        uint256 public nonce;
        uint256 public mode;
        mapping(uint256 => address) public ownerOf;

        constructor(address core_) {
            core = core_;
        }

        function configure(uint256 value) external {
            mode = value;
        }

        function advanceNonce() external {
            ++nonce;
        }

        function phasePolicyHash(uint256, bytes32) external pure returns (bytes32) {
            return POLICY;
        }

        function previewSingleStepMintOperation(
            IStreamMintManager.MintBatch calldata batch,
            bytes calldata
        ) external view returns (bytes32 root, bytes32[] memory ids) {
            return _identity(batch);
        }

        function executeSingleStepMint(IStreamMintManager.MintBatch calldata batch, bytes calldata)
            external
            returns (uint256[] memory tokens, bytes32 root, bytes32[] memory ids)
        {
            require(mode != 1, "mint rejected");
            (root, ids) = _identity(batch);
            if (mode == 2) root = bytes32(uint256(root) + 1);
            if (mode == 3) ids[0] = bytes32(uint256(ids[0]) + 1);
            tokens = new uint256[](1);
            tokens[0] = ++nonce;
            ownerOf[tokens[0]] = batch.initialRecipients[0];
            address recipient = batch.initialRecipients[0];
            if (recipient.code.length != 0) {
                require(
                    IERC721Receiver(recipient)
                            .onERC721Received(msg.sender, address(0), tokens[0], "")
                        == IERC721Receiver.onERC721Received.selector,
                    "receiver magic"
                );
            }
        }

        function _identity(IStreamMintManager.MintBatch calldata batch)
            private
            view
            returns (bytes32 root, bytes32[] memory ids)
        {
            root = keccak256(abi.encode(batch, msg.sender, nonce));
            ids = new bytes32[](1);
            ids[0] = keccak256(abi.encode(root, uint256(0)));
        }
    }

    /// @dev Exact token normally; faults affect only adapter->wallet transfer, not escrow transferFrom.
    contract SaleFundingTokenMock {
        mapping(address => uint256) public balanceOf;
        mapping(address => mapping(address => uint256)) public allowance;
        uint8 public mode;
        uint8 public approvalMode;
        uint256 public transferGas;
        address public callback;
        bytes public callbackData;

        function mint(address who, uint256 amount) external {
            balanceOf[who] += amount;
        }

        function configure(uint8 value) external {
            mode = value;
        }

        function configureApproval(uint8 value) external {
            approvalMode = value;
        }

        function setAllowance(address from, address spender, uint256 value) external {
            allowance[from][spender] = value;
        }

        function setCallback(address who, bytes calldata data) external {
            callback = who;
            callbackData = data;
        }

        function approve(address who, uint256 amount) external returns (bool) {
            if (approvalMode == 1) return false;
            if (approvalMode == 2) return true;
            allowance[msg.sender][who] = amount;
            return true;
        }

        function transferFrom(address from, address to, uint256 amount) external returns (bool) {
            allowance[from][msg.sender] -= amount;
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
            return true;
        }

        function transfer(address to, uint256 amount) external returns (bool) {
            transferGas = gasleft();
            uint8 selected = mode;
            if (selected == 1) revert("recipient deposit refused");
            if (selected == 3) return true;
            balanceOf[msg.sender] -= amount;
            balanceOf[to] += selected == 4 ? amount - 1 : amount;
            if (callback != address(0)) {
                (bool ok, bytes memory reason) = callback.call(callbackData);
                if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
            }
            if (selected == 2) return false; // Partial movement must not survive into fallback.
            if (selected == 5) assembly ("memory-safe") { return(0, 0) }
            if (selected == 6) {
                assembly ("memory-safe") {
                    mstore(0, 1)
                    return(0, 64)
                }
            }
            if (selected == 7) assembly ("memory-safe") { for { } 1 { } { } }
            if (selected == 8) assembly ("memory-safe") { revert(mload(0x40), 65536) }
            return true;
        }
    }

    contract SaleFundingReceiver is IERC721Receiver {
        address public wallet;
        address public token;
        IStreamRevenueEscrow public escrow;
        bytes32 public profile;
        bytes32 public revenueClass;
        uint256 public observedWallet;
        uint256 public observedEscrow;
        bool public reject;
        address public reentryTarget;
        bytes public reentryData;
        bytes public reentryReason;

        function reenter(address target, bytes calldata data) external {
            reentryTarget = target;
            reentryData = data;
        }

        function configure(
            address wallet_,
            address token_,
            IStreamRevenueEscrow escrow_,
            bytes32 class_,
            bytes32 profile_,
            bool reject_
        ) external {
            wallet = wallet_;
            token = token_;
            escrow = escrow_;
            revenueClass = class_;
            profile = profile_;
            reject = reject_;
        }

        function onERC721Received(address, address, uint256, bytes calldata)
            external
            returns (bytes4)
        {
            require(!reject, "receiver rejected");
            observedWallet =
                token == address(0) ? wallet.balance : SaleFundingTokenMock(token).balanceOf(wallet);
            observedEscrow = escrow.escrowOwed(revenueClass, profile, wallet, token);
            if (reentryTarget != address(0)) {
                (bool ok, bytes memory reason) = reentryTarget.call(reentryData);
                require(!ok, "reentry unexpectedly succeeded");
                reentryReason = reason;
            }
            return IERC721Receiver.onERC721Received.selector;
        }
    }
