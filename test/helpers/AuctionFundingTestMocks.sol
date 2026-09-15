// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./RevenueResolverTestMocks.sol";
import "./SaleFundingTestMocks.sol";

interface AuctionFundingFaultVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
}

/// @dev NFT custody/selected-pointer boundary, not the actual current Core runtime.
contract AuctionFundingCoreMock is RevenueResolverCoreMock {
    mapping(uint256 => address) public ownerOf;
    uint256 public minted;
    address public manager;

    function setManager(address value) external {
        manager = value;
    }

    function mint(address recipient) external returns (uint256 id) {
        require(msg.sender == manager, "only fixture manager");
        id = ++minted;
        ownerOf[id] = recipient;
        if (recipient.code.length != 0) {
            require(
                IERC721Receiver(recipient).onERC721Received(msg.sender, address(0), id, "")
                    == IERC721Receiver.onERC721Received.selector,
                "fixture mint receiver"
            );
        }
    }

    function safeTransferFrom(address from, address recipient, uint256 id) external {
        require(
            msg.sender == from && ownerOf[id] == from && recipient != address(0),
            "fixture NFT authority"
        );
        ownerOf[id] = recipient;
        if (recipient.code.length != 0) {
            require(
                IERC721Receiver(recipient).onERC721Received(msg.sender, from, id, "")
                    == IERC721Receiver.onERC721Received.selector,
                "fixture transfer receiver"
            );
        }
    }
}

contract AuctionFundingManagerMock {
    AuctionFundingCoreMock public immutable core;
    uint256 public nonce;
    uint256 public mode;
    bytes32 public constant POLICY = keccak256("auction policy");

    constructor(AuctionFundingCoreMock core_) {
        core = core_;
    }

    function configure(uint256 value) external {
        mode = value;
    }

    function phasePolicyHash(uint256, bytes32) external pure returns (bytes32) {
        return POLICY;
    }

    function previewSingleStepMintOperation(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata
    ) external view returns (bytes32 root, bytes32[] memory ids) {
        (root, ids) = _identity(batch);
        if (mode == 3) root = bytes32(0);
        if (mode == 4) ids = new bytes32[](0);
    }

    function executeSingleStepMint(IStreamMintManager.MintBatch calldata batch, bytes calldata)
        external
        returns (uint256[] memory tokens, bytes32 root, bytes32[] memory ids)
    {
        require(mode != 5, "fixture mint rejected");
        (root, ids) = _identity(batch);
        if (mode == 1) root = bytes32(uint256(root) + 1);
        if (mode == 2) ids[0] = bytes32(uint256(ids[0]) + 1);
        ++nonce;
        tokens = new uint256[](1);
        tokens[0] = core.mint(batch.initialRecipients[0]);
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

contract AuctionFundingMoneyReceiver {
    bool public reject;
    address public reentryTarget;
    bytes public reentryData;
    bytes public reentryReason;

    function configure(bool rejected, address target, bytes calldata data) external {
        reject = rejected;
        reentryTarget = target;
        reentryData = data;
    }

    receive() external payable {
        require(!reject, "refund refused");
        if (reentryTarget != address(0)) {
            (bool ok, bytes memory reason) = reentryTarget.call(reentryData);
            require(!ok, "refund reentry succeeded");
            reentryReason = reason;
        }
    }
}
