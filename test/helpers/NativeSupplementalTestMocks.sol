// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./UniversalSettlementTestMocks.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";

/// @dev Explicit Core token identity seam, including retained burned identity.
contract SupplementalCoreMock is UniversalCoreMock, IStreamCoreIdentity {
    mapping(uint256 => uint256) public collections;
    mapping(uint256 => bool) public burns;
    mapping(uint256 => bool) public incomplete;

    function setIncomplete(uint256 id, bool value) external {
        incomplete[id] = value;
    }

    function setIdentity(uint256 token, uint256 collection, bool burned) external {
        collections[token] = collection;
        burns[token] = burned;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (collections[id] != 0, collections[id], id, burns[id]);
    }

    function tokenLifecycle(uint256 id) external view returns (uint8) {
        return collections[id] == 0 ? 0 : incomplete[id] ? 1 : burns[id] ? 3 : 2;
    }

    function coordinatorAtMint(uint256) external pure returns (address) {
        return address(0);
    }
}

/// @dev Actual mock execution consumes the preview root and establishes token association atomically.
///      This is not the canonical Manager/ledger/Core integration proof.
contract SupplementalManagerMock {
    address public immutable core;
    address public immutable moduleRegistry;
    bytes32 public constant POLICY = keccak256("supplemental manager policy");
    uint256 public nonce;
    bool public reject;
    mapping(bytes32 => bool) public isOperationRootUsed;
    mapping(uint256 => address) public ownerOf;

    constructor(address c, address registry) {
        core = c;
        moduleRegistry = registry;
    }

    function setReject(bool value) external {
        reject = value;
    }

    function clearRoot(bytes32 root) external {
        isOperationRootUsed[root] = false;
    }

    function previewSingleStepMintOperation(IStreamMintManager.MintBatch calldata b, bytes calldata)
        external
        view
        returns (bytes32 root, bytes32[] memory ids)
    {
        return _identity(b);
    }

    function executeSingleStepMint(IStreamMintManager.MintBatch calldata b, bytes calldata)
        external
        returns (uint256[] memory tokens, bytes32 root, bytes32[] memory ids)
    {
        require(!reject, "mint rejected");
        (root, ids) = _identity(b);
        require(!isOperationRootUsed[root]);
        isOperationRootUsed[root] = true;
        tokens = new uint256[](1);
        tokens[0] = ++nonce;
        ownerOf[nonce] = b.initialRecipients[0];
        SupplementalCoreMock(core).setIdentity(nonce, b.collectionId, false);
        if (b.initialRecipients[0].code.length != 0) {
            require(
                IERC721Receiver(b.initialRecipients[0])
                    .onERC721Received(msg.sender, address(0), nonce, "")
                == IERC721Receiver.onERC721Received.selector
            );
        }
    }

    function _identity(IStreamMintManager.MintBatch calldata b)
        private
        view
        returns (bytes32 root, bytes32[] memory ids)
    {
        root = keccak256(abi.encode(b, msg.sender, nonce));
        ids = new bytes32[](1);
        ids[0] = keccak256(abi.encode(root, uint256(0)));
    }
}

/// @dev Canonically admitted test producer with real floor recorder call followed by mock mint.
///      Mutable test setters intentionally model a hostile admitted consumer. No clearing-sale acceptance claim.
contract SupplementalProducerMock is IStreamNativeClearingSaleBinding {
    address public immutable core;
    address public immutable moduleRegistry;
    address public immutable revenueResolver;
    SupplementalManagerMock public immutable mintManager;
    bytes32 public immutable mintManagerCodeHash;
    StreamPrimarySaleSettlement public immutable primarySaleSettlement;
    StreamNativeSettlementTypes.SaleLifecycleBinding private lifecycle;
    mapping(bytes32 => StreamNativeSettlementTypes.NativeSettlementCandidate) private floors;
    mapping(bytes32 => StreamNativeSupplementalTypes.ClearingPurchaseFacts) private facts;
    mapping(bytes32 => bytes32) private active;
    uint256 public factsFault;
    uint256 public latchFault;
    bool public capability = true;

    constructor(StreamPrimarySaleSettlement recorder, SupplementalManagerMock m) {
        primarySaleSettlement = recorder;
        mintManager = m;
        mintManagerCodeHash = address(m).codehash;
        core = recorder.core();
        moduleRegistry = recorder.moduleRegistry();
        revenueResolver = address(recorder.revenueResolver());
    }

    function capture() external {
        lifecycle = StreamNativeSettlementAdmission.capture(moduleRegistry, address(this));
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamNativeSaleBinding).interfaceId
            || (capability && id == type(IStreamNativeClearingSaleBinding).interfaceId);
    }

    function nativeSaleLifecycleBinding(bytes32)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        return lifecycle;
    }

    function configureFault(uint256 f, uint256 l, bool cap) external {
        factsFault = f;
        latchFault = l;
        capability = cap;
    }

    function clearingPurchaseFacts(bytes32 id)
        external
        view
        returns (StreamNativeSupplementalTypes.ClearingPurchaseFacts memory p)
    {
        p = facts[id];
        uint256 f = factsFault;
        if (f == 1) revert("facts failed");
        if (f == 2) assembly ("memory-safe") { return(p, 416) }
        if (f == 3) assembly ("memory-safe") {
            let out := mload(0x40)
            return(out, 65536)
        }
        if (f == 4) assembly ("memory-safe") {
            mstore(add(p, 288), 2)
            return(p, 448)
        }
        if (f == 5) assembly ("memory-safe") {
            mstore(add(p, 384), shl(64, 1))
            return(p, 448)
        }
        if (f == 6) assembly ("memory-safe") {
            mstore(add(p, 416), 256)
            return(p, 448)
        }
        if (f == 7) assembly ("memory-safe") { for { } 1 { } { } }
        if (f == 8) {
            StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c;
            (bool ok, bytes memory reason) = address(primarySaleSettlement)
                .staticcall(
                    abi.encodeCall(
                        IStreamNativeSupplementalSettlement.settleNativeSupplementalRevenueFromAdapter,
                        (c)
                    )
                );
            require(
                !ok
                    && keccak256(reason)
                        == keccak256(abi.encodeWithSignature("ReentrancyGuardReentrantCall()")),
                "exact recorder reentry guard"
            );
        }
    }

    function activeNativeSupplementalSettlement(bytes32 id) external view returns (bytes32) {
        if (latchFault == 1) return 0;
        if (latchFault == 2) assembly ("memory-safe") { return(0, 0) }
        if (latchFault == 3) assembly ("memory-safe") {
            mstore(0, 1)
            mstore(32, 0)
            return(0, 64)
        }
        return active[id];
    }

    function previewFloor(
        IStreamMintManager.MintBatch calldata b,
        uint256 number,
        StreamPrimarySettlementTypes.PrimaryRights memory rights,
        bytes32 policy
    ) public view returns (StreamNativeSettlementTypes.NativeSettlementCandidate memory c) {
        c.saleAdapter = address(this);
        c.executor = b.payer;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            keccak256("clearing sale"),
            keccak256("PRIMARY_SALE"),
            0,
            b.collectionId,
            0,
            1,
            b.payer,
            b.payer,
            b.beneficiaries[0],
            1000,
            policy
        );
        c.lifecycleBinding = lifecycle;
        c.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, number, 1, b.authorizationId);
        c.orchestrationOrder = 1;
        c.mintManager = address(mintManager);
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) = mintManager.previewSingleStepMintOperation(b, "");
        c.operationId = ids[0];
        c.currentPolicyHash = mintManager.POLICY();
        c.boundPolicyHash = c.currentPolicyHash;
        c.rights = rights;
        c.saleExecutionHash = keccak256(abi.encode(b));
        c.executionBinding.executionId = StreamNativeSettlementHash.executionId(c);
    }

    function floorAndMint(
        IStreamMintManager.MintBatch calldata b,
        uint256 number,
        StreamPrimarySettlementTypes.PrimaryRights memory rights,
        bytes32 policy
    ) external payable returns (bytes32 id) {
        require(msg.sender == b.payer && msg.value == 1000);
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c =
            previewFloor(b, number, rights, policy);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            primarySaleSettlement.settleNativePrimarySaleFromAdapter{ value: msg.value }(c);
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            mintManager.executeSingleStepMint(b, "");
        require(
            root == c.operationIdentityCommitment && ids.length == 1 && ids[0] == c.operationId
                && tokens.length == 1
        );
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(this),
                c.sale.settlementId,
                b.payer,
                number
            )
        );
        require(facts[id].status == 0);
        floors[id] = c;
        facts[id] = StreamNativeSupplementalTypes.ClearingPurchaseFacts(
            result.settlementKey,
            result.candidateCommitment,
            c.executionBinding.saleAuthorizationDigest,
            number,
            tokens[0],
            ids[0],
            5000,
            1000,
            3000,
            false,
            0,
            3000,
            uint64(block.timestamp + 1 days),
            1
        );
    }

    function candidate(
        bytes32 id,
        StreamPrimarySettlementTypes.PrimaryRights memory rights,
        bytes32 policy,
        address executor
    ) external view returns (StreamNativeSupplementalTypes.NativeSupplementalCandidate memory) {
        return StreamNativeSupplementalTypes.NativeSupplementalCandidate(
            floors[id], id, executor, facts[id], rights, policy
        );
    }

    function replaceFacts(
        bytes32 id,
        StreamNativeSupplementalTypes.ClearingPurchaseFacts calldata p
    ) external {
        facts[id] = p;
    }

    function supplement(StreamNativeSupplementalTypes.NativeSupplementalCandidate calldata c)
        external
        payable
        returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory r)
    {
        active[c.purchaseId] =
            StreamNativeSupplementalHash.candidateCommitment(address(primarySaleSettlement), c);
        r = primarySaleSettlement.settleNativeSupplementalRevenueFromAdapter{ value: msg.value }(c);
        delete active[c.purchaseId];
    }
}
