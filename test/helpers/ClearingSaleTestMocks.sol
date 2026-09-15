// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./RefundWindowTestMocks.sol";
import "../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";

/// @dev Explicit domain Core seam; identity is established by the mock mint in the same frame.
contract ClearingRuntimeCore is RefundRuntimeCore, IStreamCoreIdentity {
    mapping(uint256 => uint256) public tokenCollection;
    mapping(uint256 => bool) public burned;

    function setIdentity(uint256 id, uint256 collection, bool isBurned) external {
        tokenCollection[id] = collection;
        burned[id] = isBurned;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (tokenCollection[id] != 0, tokenCollection[id], id, burned[id]);
    }

    function tokenLifecycle(uint256 id) external view returns (uint8) {
        return tokenCollection[id] == 0 ? 0 : burned[id] ? 3 : 2;
    }

    function coordinatorAtMint(uint256) external pure returns (address) {
        return address(0);
    }
}

/// @dev Refund-runtime Manager seam with atomic consumed-root/token identity hooks; not actual Core/ledger.
contract ClearingRuntimeManager {
    address public immutable core;
    address public immutable moduleRegistry;
    bytes32 public currentPolicy = keccak256("refund phase policy");
    bytes32 public priorPolicy;
    uint64 public graceUntil;
    uint64 public phaseEnd = 20_000_000;
    bool public paused;
    bool public admitted = true;
    bool public unavailable;
    uint256 public nonce;
    uint256 public mode;
    mapping(uint256 => address) public ownerOf;
    mapping(bytes32 => bool) public isOperationRootUsed;
    bytes32 public lastAuthorizationId;
    bytes32 public lastContextHash;
    address public lastPayer;
    IStreamMintManager.MintGateConfig private _gate;

    constructor(address c, address r) {
        core = c;
        moduleRegistry = r;
    }

    function isStreamMintManager() external pure returns (bool) {
        return true;
    }

    function setPhase(bool p, uint64 end, bool allowed) external {
        paused = p;
        phaseEnd = end;
        admitted = allowed;
    }

    function setUnavailable(bool value) external {
        unavailable = value;
    }

    function setPolicy(bytes32 current, bytes32 prior, uint64 grace) external {
        currentPolicy = current;
        priorPolicy = prior;
        graceUntil = grace;
    }

    function setMode(uint256 value) external {
        mode = value;
    }

    function phasePolicyHash(uint256, bytes32) external view returns (bytes32) {
        require(!unavailable, "phase unavailable");
        return currentPolicy;
    }

    function phasePolicyGrace(uint256, bytes32) external view returns (bytes32, uint64) {
        require(!unavailable, "phase unavailable");
        return (priorPolicy, graceUntil);
    }

    function phase(uint256, bytes32)
        external
        view
        returns (bool, IStreamMintManager.MintPhaseConfig memory c)
    {
        require(!unavailable, "phase unavailable");
        c.paused = paused;
        c.endTime = phaseEnd;
        c.maxBatchQuantity = 1;
        return (true, c);
    }

    function phaseExecutor(uint256, bytes32, address) external view returns (bool) {
        return admitted;
    }

    function setGate(address target) external {
        _gate.gate = target;
        _gate.gateCodehash = target.codehash;
    }

    function phaseGate(uint256, bytes32)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory)
    {
        return _gate;
    }

    function phaseCounterIds(uint256, bytes32) external pure returns (bytes32[] memory ids) {
        ids = new bytes32[](0);
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
        require(!isOperationRootUsed[root], "operation replay");
        isOperationRootUsed[root] = true;
        tokens[0] = ++nonce;
        ClearingRuntimeCore(core).setIdentity(tokens[0], batch.collectionId, false);
        ownerOf[tokens[0]] = batch.initialRecipients[0];
        lastAuthorizationId = batch.authorizationId;
        lastContextHash = batch.contextHash;
        lastPayer = batch.payer;
        if (batch.initialRecipients[0].code.length != 0) {
            require(
                IERC721Receiver(batch.initialRecipients[0])
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
        require(
            !unavailable && !paused && admitted && (phaseEnd == 0 || block.timestamp <= phaseEnd),
            "phase closed"
        );
        require(
            batch.expectedPolicyHash == currentPolicy
                || (batch.expectedPolicyHash == priorPolicy && block.timestamp <= graceUntil),
            "policy stale"
        );
        root = keccak256(abi.encode(batch, msg.sender, nonce));
        ids = new bytes32[](1);
        ids[0] = keccak256(abi.encode(root, uint256(0)));
    }
}
