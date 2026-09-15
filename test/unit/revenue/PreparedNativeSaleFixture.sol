// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../../smart-contracts/domains/mint/StreamSaleSignatures.sol";
import "../../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../../smart-contracts/vendor/openzeppelin/IERC721Receiver.sol";

/// @dev Registered adversarial sale boundary, not the future auction product. The same
/// signed intent is retried unchanged; only test-controlled receiver/callback faults vary.
contract PreparedNativeSaleFixture is IStreamPreparedNativeSaleBinding, IERC721Receiver, ERC165, ReentrancyGuard {
    address public immutable override core;
    address public immutable override moduleRegistry;
    address public immutable override mintManager;
    address public immutable override revenueResolver;
    address public immutable override primarySaleSettlement;
    bytes32 public immutable override settlementCodeHash;
    address public immutable signer;
    address public immutable controller;
    StreamNativeSettlementTypes.SaleLifecycleBinding private _lifecycle;
    StreamPreparedNativeSettlementTypes.Intent private _intent;
    bytes32 private _intentHash;
    mapping(bytes32 => bool) public used;
    uint256 public fault;
    bool public callbackReentryRejected;
    bool public receiverReentryRejected;
    bool public receiverSawOfficialPayment;
    StreamPreparedNativeSettlementTypes.Facts private _lastFacts;
    bytes private _reentryData;
    bytes public lastRecorderReturn;
    uint256 private _officialBefore;

    constructor(StreamMintManager manager, StreamPrimarySaleSettlement recorder, address authority) {
        core = address(manager.core());
        moduleRegistry = address(manager.moduleRegistry());
        mintManager = address(manager);
        revenueResolver = address(recorder.revenueResolver());
        primarySaleSettlement = address(recorder);
        settlementCodeHash = address(recorder).codehash;
        signer = authority;
        controller = msg.sender;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamPreparedNativeSaleBinding).interfaceId || super.supportsInterface(id);
    }

    function open() external {
        require(msg.sender == controller && _lifecycle.saleCreatedAt == 0, "open once");
        _lifecycle = StreamPreparedNativeSettlementAdmission.capture(moduleRegistry, address(this));
    }

    function lastFacts() external view returns (StreamPreparedNativeSettlementTypes.Facts memory) { return _lastFacts; }

    function configureFault(uint256 value) external {
        require(msg.sender == controller, "controller");
        fault = value;
    }

    function preparedNativeSaleLifecycle(bytes32 saleId) external view returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory) {
        require(saleId == keccak256("prepared fixture sale"), "sale");
        return _lifecycle;
    }

    function activePreparedNativeIntent(bytes32 hash) external view returns (StreamPreparedNativeSettlementTypes.Intent memory) {
        require(hash != 0 && hash == _intentHash, "active intent");
        return _intent;
    }

    function authorizationDigest(StreamPreparedNativeSettlementTypes.Intent memory intent, uint64 deadline) public view returns (bytes32) {
        intent.saleAuthorizationDigest = 0;
        intent.saleExecutionHash = 0;
        bytes32 domain = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("PreparedNativeSaleFixture"), keccak256("1"), block.chainid, address(this)
        ));
        bytes32 body = keccak256(abi.encode(keccak256("PreparedFixtureAuthorization(bytes32 intentFieldsHash,uint64 deadline)"), keccak256(abi.encode(intent)), deadline));
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function batch(StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory tokenData)
        public view returns (IStreamMintManager.MintBatch memory b, bytes32 hash)
    {
        hash = StreamPreparedNativeSettlementHash.intentHash(address(this), primarySaleSettlement, intent);
        b.collectionId = intent.collectionId;
        b.phaseId = intent.phaseId;
        b.payer = intent.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = address(this);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = intent.beneficiary;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = intent.mintCommitment;
        b.expectedPolicyHash = intent.boundMintPolicyHash;
        b.authorizationId = hash;
        b.contextHash = StreamPreparedNativeSettlementHash.mintContext(mintManager, address(this), hash);
    }

    function preview(StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory tokenData)
        external view returns (bytes32 root, bytes32[] memory ids)
    {
        (IStreamMintManager.MintBatch memory b,) = batch(intent, tokenData);
        return IStreamPreparedNativeMint(mintManager).previewPreparedNativeMintOperation(b, "");
    }

    function execute(StreamPreparedNativeSettlementTypes.Intent calldata intent, bytes calldata tokenData,
        uint64 deadline, bytes calldata signature)
        external payable nonReentrant returns (uint256 tokenId, bytes32 root, bytes32 operationId, StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        bytes32 digest = authorizationDigest(intent, deadline);
        require(block.timestamp <= deadline && StreamSaleSignatures.isValid(signer, digest, signature), "signature/deadline");
        require(msg.sender == intent.executor && msg.sender == intent.payer && msg.value == intent.amount, "payer/value");
        require(intent.saleAuthorizationDigest == digest && intent.saleExecutionHash == keccak256(abi.encode(digest, intent.executionNonce)), "signed identity");
        require(keccak256(tokenData) == intent.contentSelectionHash && !used[digest], "content/replay");
        (IStreamMintManager.MintBatch memory b, bytes32 hash) = batch(intent, tokenData);
        used[digest] = true;
        _intent = intent;
        _intentHash = hash;
        _reentryData = msg.data;
        _officialBefore = IStreamPrimarySaleSettlement(primarySaleSettlement).totalOfficialSettled(address(0));
        (tokenId, root, operationId, result) = IStreamPreparedNativeMint(mintManager).executePreparedNativeMint(b, "", hash);
        delete _intent;
        delete _intentHash;
        delete _reentryData;
    }

    function onPreparedNativeMint(StreamPreparedNativeSettlementTypes.Facts calldata facts)
        external returns (bytes4 magic, StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        require(msg.sender == mintManager && facts.intentHash == _intentHash && _intentHash != 0, "active manager only");
        StreamPreparedNativeSettlementTypes.Facts memory active = IStreamPreparedNativeMint(mintManager).activePreparedNativeMint();
        require(keccak256(abi.encode(active)) == keccak256(abi.encode(facts)), "full actual facts");
        require(IStreamCore(core).preparedMint(facts.tokenId).operationId == facts.operationId && IStreamCore(core).tokenLifecycle(facts.tokenId) == 1, "prepared first");
        _lastFacts = facts;
        if (fault == 1) revert("callback failure");
        if (fault == 2) return (this.onPreparedNativeMint.selector, result);
        if (fault == 4) {
            (bool ok,) = address(this).call(_reentryData);
            callbackReentryRejected = !ok;
            (IStreamMintManager.MintBatch memory b,) = batch(_intent, IStreamCore(core).tokenData(facts.tokenId));
            (ok,) = mintManager.call(abi.encodeCall(IStreamPreparedNativeMint.executePreparedNativeMint, (b, bytes(""), _intentHash)));
            require(!ok, "manager reentry");
        }
        StreamPreparedNativeSettlementTypes.Facts memory submitted = facts;
        if (fault >= 100 && fault < 118) {
            uint256 field = fault - 100;
            assembly ("memory-safe") {
                let p := add(submitted, mul(field, 32))
                mstore(p, xor(mload(p), 1))
            }
        }
        if (fault == 7) {
            (bool ok, bytes memory raw) = primarySaleSettlement.call{value: _intent.amount}(
                abi.encodeCall(IStreamPreparedNativePrimarySaleSettlement.settlePreparedNativePrimarySale, (submitted, _intent)));
            if (!ok) { assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) } }
            require(raw.length == 384, "exact original recorder ABI");
            lastRecorderReturn = raw;
            result = abi.decode(raw, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        } else {
            result = IStreamPreparedNativePrimarySaleSettlement(primarySaleSettlement).settlePreparedNativePrimarySale{value: _intent.amount}(submitted, _intent);
        }
        if (fault == 3) result.amount += 1;
        if (fault == 5) return (bytes4(0), result);
        return (this.onPreparedNativeMint.selector, result);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(msg.sender == core, "core receiver");
        require(fault != 6, "receiver failure");
        receiverSawOfficialPayment = IStreamPrimarySaleSettlement(primarySaleSettlement).totalOfficialSettled(address(0)) == _officialBefore + _intent.amount;
        if (fault == 4) {
            (bool ok,) = address(this).call(_reentryData);
            receiverReentryRejected = !ok;
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}
