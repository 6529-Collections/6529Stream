// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/IStreamModuleRegistry.sol";

/// @notice Local-only 2-of-n execution wallet used by the Governance V2
///         material-holder rehearsal. It models the two properties the protocol
///         depends on: threshold-approved calls originate from the wallet itself,
///         and ERC-1271 approved-digest checks use the same threshold.
contract StreamGovernanceV2SafeRehearsal {
    bytes4 private constant _ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 private constant _ERC1271_INVALID_VALUE = 0xffffffff;

    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint64 approvalCount;
        bool executed;
        bytes returnData;
    }

    mapping(address => bool) public isOwner;
    address[] private _owners;
    uint64 public threshold;
    Transaction[] private _transactions;
    mapping(uint256 => mapping(address => bool)) public transactionApprovedBy;
    mapping(bytes32 => mapping(address => bool)) public digestApprovedBy;
    mapping(bytes32 => uint64) public digestApprovalCount;
    uint256 public receivedNative;
    address public lastNativeSender;

    event RehearsalSafeTransactionSubmitted(
        uint256 indexed transactionId, address indexed target, uint256 value, bytes32 dataHash
    );
    event RehearsalSafeTransactionApproved(
        uint256 indexed transactionId, address indexed owner, uint64 approvalCount
    );
    event RehearsalSafeTransactionExecuted(
        uint256 indexed transactionId, address indexed target, uint256 value, bytes returnData
    );
    event RehearsalSafeDigestApproved(
        bytes32 indexed digest, address indexed owner, uint64 approvalCount
    );

    error RehearsalSafeNotOwner(address actor);
    error RehearsalSafeInvalidConfiguration();
    error RehearsalSafeUnknownTransaction(uint256 transactionId);
    error RehearsalSafeAlreadyApproved(uint256 transactionId, address owner);
    error RehearsalSafeAlreadyExecuted(uint256 transactionId);
    error RehearsalSafeThresholdNotMet(uint256 transactionId, uint64 approvals, uint64 required);

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert RehearsalSafeNotOwner(msg.sender);
        _;
    }

    constructor(address[] memory owners_, uint64 threshold_) {
        if (owners_.length < 2 || threshold_ < 2 || threshold_ > owners_.length) {
            revert RehearsalSafeInvalidConfiguration();
        }
        for (uint256 i = 0; i < owners_.length; i++) {
            address owner = owners_[i];
            if (owner == address(0) || isOwner[owner]) {
                revert RehearsalSafeInvalidConfiguration();
            }
            isOwner[owner] = true;
            _owners.push(owner);
        }
        threshold = threshold_;
    }

    function implementationName() external pure returns (string memory) {
        return "StreamGovernanceV2SafeRehearsal";
    }

    function ownerCount() external view returns (uint256) {
        return _owners.length;
    }

    function ownerAt(uint256 index) external view returns (address) {
        return _owners[index];
    }

    function transactionCount() external view returns (uint256) {
        return _transactions.length;
    }

    function transaction(uint256 transactionId)
        external
        view
        returns (
            address target,
            uint256 value,
            bytes memory data,
            uint64 approvalCount,
            bool executed
        )
    {
        if (transactionId >= _transactions.length) {
            revert RehearsalSafeUnknownTransaction(transactionId);
        }
        Transaction storage txn = _transactions[transactionId];
        return (txn.target, txn.value, txn.data, txn.approvalCount, txn.executed);
    }

    function transactionReturnData(uint256 transactionId) external view returns (bytes memory) {
        if (transactionId >= _transactions.length) {
            revert RehearsalSafeUnknownTransaction(transactionId);
        }
        return _transactions[transactionId].returnData;
    }

    function submitTransaction(address target, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (uint256 transactionId)
    {
        if (target == address(0)) revert RehearsalSafeInvalidConfiguration();
        transactionId = _transactions.length;
        _transactions.push();
        Transaction storage txn = _transactions[transactionId];
        txn.target = target;
        txn.value = value;
        txn.data = data;
        emit RehearsalSafeTransactionSubmitted(transactionId, target, value, keccak256(data));
    }

    function approveTransaction(uint256 transactionId) external onlyOwner {
        if (transactionId >= _transactions.length) {
            revert RehearsalSafeUnknownTransaction(transactionId);
        }
        Transaction storage txn = _transactions[transactionId];
        if (txn.executed) revert RehearsalSafeAlreadyExecuted(transactionId);
        if (transactionApprovedBy[transactionId][msg.sender]) {
            revert RehearsalSafeAlreadyApproved(transactionId, msg.sender);
        }
        transactionApprovedBy[transactionId][msg.sender] = true;
        txn.approvalCount += 1;
        emit RehearsalSafeTransactionApproved(transactionId, msg.sender, txn.approvalCount);
    }

    function executeTransaction(uint256 transactionId)
        external
        onlyOwner
        returns (bytes memory returnData)
    {
        if (transactionId >= _transactions.length) {
            revert RehearsalSafeUnknownTransaction(transactionId);
        }
        Transaction storage txn = _transactions[transactionId];
        if (txn.executed) revert RehearsalSafeAlreadyExecuted(transactionId);
        if (txn.approvalCount < threshold) {
            revert RehearsalSafeThresholdNotMet(transactionId, txn.approvalCount, threshold);
        }
        txn.executed = true;
        (bool ok, bytes memory result) = txn.target.call{ value: txn.value }(txn.data);
        if (!ok) _bubble(result);
        txn.returnData = result;
        emit RehearsalSafeTransactionExecuted(transactionId, txn.target, txn.value, result);
        return result;
    }

    function approveDigest(bytes32 digest) external onlyOwner {
        if (!digestApprovedBy[digest][msg.sender]) {
            digestApprovedBy[digest][msg.sender] = true;
            digestApprovalCount[digest] += 1;
            emit RehearsalSafeDigestApproved(digest, msg.sender, digestApprovalCount[digest]);
        }
    }

    function isValidSignature(bytes32 digest, bytes calldata) external view returns (bytes4) {
        return
            digestApprovalCount[digest] >= threshold ? _ERC1271_MAGIC_VALUE : _ERC1271_INVALID_VALUE;
    }

    function erc1271Posture() external pure returns (bytes32) {
        return keccak256("ERC1271_APPROVED_DIGEST_OWNER_THRESHOLD");
    }

    function _bubble(bytes memory returnData) private pure {
        if (returnData.length == 0) revert RehearsalSafeInvalidConfiguration();
        assembly ("memory-safe") {
            revert(add(returnData, 0x20), mload(returnData))
        }
    }

    receive() external payable {
        receivedNative += msg.value;
        lastNativeSender = msg.sender;
    }
}

/// @notice Separate local-only timelock executor for the pinned reference
///         governor rehearsal. The governor binding is one-way and scheduling
///         never executes an operation in the same transaction.
contract StreamReferenceTimelockRehearsal {
    struct Operation {
        uint64 readyAt;
        bool executed;
    }

    address public bootstrapAdmin;
    address public governor;
    uint64 public minimumDelaySeconds;
    mapping(bytes32 => Operation) public operations;
    uint256 public receivedNative;
    address public lastNativeSender;

    event RehearsalTimelockGovernorBound(address indexed governor);
    event RehearsalTimelockOperationScheduled(bytes32 indexed operationId, uint64 readyAt);
    event RehearsalTimelockOperationExecuted(bytes32 indexed operationId, bytes returnData);

    error RehearsalTimelockUnauthorized(address actor);
    error RehearsalTimelockAlreadyBound();
    error RehearsalTimelockOperationExists(bytes32 operationId);
    error RehearsalTimelockOperationNotReady(bytes32 operationId, uint64 readyAt);
    error RehearsalTimelockOperationExecutedAlready(bytes32 operationId);
    error RehearsalTimelockCallFailed();

    constructor(uint64 minimumDelaySeconds_) {
        if (minimumDelaySeconds_ == 0) revert RehearsalTimelockAlreadyBound();
        bootstrapAdmin = msg.sender;
        minimumDelaySeconds = minimumDelaySeconds_;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert RehearsalTimelockUnauthorized(msg.sender);
        _;
    }

    function implementationName() external pure returns (string memory) {
        return "StreamReferenceTimelockRehearsal";
    }

    function bindGovernor(address governor_) external {
        if (msg.sender != bootstrapAdmin) revert RehearsalTimelockUnauthorized(msg.sender);
        if (governor != address(0) || governor_ == address(0)) {
            revert RehearsalTimelockAlreadyBound();
        }
        governor = governor_;
        bootstrapAdmin = address(0);
        emit RehearsalTimelockGovernorBound(governor_);
    }

    function operationId(address target, uint256 value, bytes calldata data, bytes32 salt)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(block.chainid, address(this), target, value, data, salt));
    }

    function schedule(address target, uint256 value, bytes calldata data, bytes32 salt)
        external
        onlyGovernor
        returns (bytes32 id, uint64 readyAt)
    {
        id = operationId(target, value, data, salt);
        if (operations[id].readyAt != 0) revert RehearsalTimelockOperationExists(id);
        readyAt = uint64(block.timestamp) + minimumDelaySeconds;
        operations[id] = Operation({ readyAt: readyAt, executed: false });
        emit RehearsalTimelockOperationScheduled(id, readyAt);
    }

    function execute(address target, uint256 value, bytes calldata data, bytes32 salt)
        external
        payable
        onlyGovernor
        returns (bytes memory returnData)
    {
        bytes32 id = operationId(target, value, data, salt);
        Operation storage operation = operations[id];
        if (operation.executed) revert RehearsalTimelockOperationExecutedAlready(id);
        if (operation.readyAt == 0 || block.timestamp < operation.readyAt) {
            revert RehearsalTimelockOperationNotReady(id, operation.readyAt);
        }
        if (msg.value != value) revert RehearsalTimelockCallFailed();
        operation.executed = true;
        (bool ok, bytes memory result) = target.call{ value: value }(data);
        if (!ok) _bubble(result);
        emit RehearsalTimelockOperationExecuted(id, result);
        return result;
    }

    function _bubble(bytes memory returnData) private pure {
        if (returnData.length == 0) revert RehearsalTimelockCallFailed();
        assembly ("memory-safe") {
            revert(add(returnData, 0x20), mload(returnData))
        }
    }

    receive() external payable {
        receivedNative += msg.value;
        lastNativeSender = msg.sender;
    }
}

/// @notice Named local reference governor with a real voting pipeline and a
///         separate timelock executor. Voting delay, voting period, quorum, and
///         timelock delay are nonzero and storage-pinned for artifact inspection.
contract StreamReferenceGovernorRehearsal {
    bytes4 private constant _ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 private constant _ERC1271_INVALID_VALUE = 0xffffffff;

    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        bytes32 descriptionHash;
        uint64 proposedAtBlock;
        uint64 proposedAt;
        uint64 voteStartBlock;
        uint64 voteEndBlock;
        uint64 queuedAt;
        uint64 readyAt;
        uint64 executedAt;
        uint64 forVotes;
        bool queued;
        bool executed;
        bytes returnData;
    }

    StreamReferenceTimelockRehearsal public timelock;
    uint64 public votingDelayBlocks;
    uint64 public votingPeriodBlocks;
    uint64 public quorumVotes;
    uint256 public proposalNonce;
    mapping(address => bool) public isVoter;
    address[] private _voters;
    mapping(bytes32 => Proposal) private _proposals;
    mapping(bytes32 => mapping(address => bool)) public proposalVotedBy;
    mapping(bytes32 => mapping(address => bool)) public digestApprovedBy;
    mapping(bytes32 => uint64) public digestApprovalCount;
    uint256 public receivedNative;
    address public lastNativeSender;

    event RehearsalGovernorProposalCreated(
        bytes32 indexed proposalId,
        address indexed proposer,
        uint64 voteStartBlock,
        uint64 voteEndBlock
    );
    event RehearsalGovernorVoteCast(
        bytes32 indexed proposalId, address indexed voter, uint64 forVotes
    );
    event RehearsalGovernorProposalQueued(
        bytes32 indexed proposalId, bytes32 indexed operationId, uint64 readyAt
    );
    event RehearsalGovernorProposalExecuted(bytes32 indexed proposalId, bytes returnData);

    error RehearsalGovernorNotVoter(address actor);
    error RehearsalGovernorInvalidConfiguration();
    error RehearsalGovernorUnknownProposal(bytes32 proposalId);
    error RehearsalGovernorVotingClosed(bytes32 proposalId);
    error RehearsalGovernorAlreadyVoted(bytes32 proposalId, address voter);
    error RehearsalGovernorQuorumNotMet(bytes32 proposalId, uint64 votes, uint64 quorum);
    error RehearsalGovernorAlreadyQueued(bytes32 proposalId);
    error RehearsalGovernorNotQueued(bytes32 proposalId);
    error RehearsalGovernorAlreadyExecuted(bytes32 proposalId);

    modifier onlyVoter() {
        if (!isVoter[msg.sender]) revert RehearsalGovernorNotVoter(msg.sender);
        _;
    }

    constructor(
        address[] memory voters_,
        uint64 votingDelayBlocks_,
        uint64 votingPeriodBlocks_,
        uint64 quorumVotes_,
        StreamReferenceTimelockRehearsal timelock_
    ) {
        if (
            voters_.length < 2 || votingDelayBlocks_ == 0 || votingPeriodBlocks_ == 0
                || quorumVotes_ < 2 || quorumVotes_ > voters_.length
                || address(timelock_) == address(0)
        ) revert RehearsalGovernorInvalidConfiguration();
        for (uint256 i = 0; i < voters_.length; i++) {
            address voter = voters_[i];
            if (voter == address(0) || isVoter[voter]) {
                revert RehearsalGovernorInvalidConfiguration();
            }
            isVoter[voter] = true;
            _voters.push(voter);
        }
        votingDelayBlocks = votingDelayBlocks_;
        votingPeriodBlocks = votingPeriodBlocks_;
        quorumVotes = quorumVotes_;
        timelock = timelock_;
    }

    function implementationName() external pure returns (string memory) {
        return "StreamReferenceGovernorRehearsal";
    }

    function voterCount() external view returns (uint256) {
        return _voters.length;
    }

    function proposal(bytes32 proposalId) external view returns (Proposal memory) {
        Proposal memory stored = _proposals[proposalId];
        if (stored.proposedAtBlock == 0) revert RehearsalGovernorUnknownProposal(proposalId);
        return stored;
    }

    function propose(address target, uint256 value, bytes calldata data, bytes32 descriptionHash)
        external
        onlyVoter
        returns (bytes32 proposalId)
    {
        uint256 nonce = proposalNonce++;
        proposalId = keccak256(
            abi.encode(
                block.chainid, address(this), target, value, keccak256(data), descriptionHash, nonce
            )
        );
        uint64 proposedAt = uint64(block.number);
        uint64 voteStart = proposedAt + votingDelayBlocks;
        uint64 voteEnd = voteStart + votingPeriodBlocks;
        Proposal storage created = _proposals[proposalId];
        created.target = target;
        created.value = value;
        created.data = data;
        created.descriptionHash = descriptionHash;
        created.proposedAtBlock = proposedAt;
        created.proposedAt = uint64(block.timestamp);
        created.voteStartBlock = voteStart;
        created.voteEndBlock = voteEnd;
        emit RehearsalGovernorProposalCreated(proposalId, msg.sender, voteStart, voteEnd);
    }

    function castVote(bytes32 proposalId) external onlyVoter {
        Proposal storage stored = _proposal(proposalId);
        if (block.number < stored.voteStartBlock || block.number > stored.voteEndBlock) {
            revert RehearsalGovernorVotingClosed(proposalId);
        }
        if (proposalVotedBy[proposalId][msg.sender]) {
            revert RehearsalGovernorAlreadyVoted(proposalId, msg.sender);
        }
        proposalVotedBy[proposalId][msg.sender] = true;
        stored.forVotes += 1;
        emit RehearsalGovernorVoteCast(proposalId, msg.sender, stored.forVotes);
    }

    function queue(bytes32 proposalId) external returns (bytes32 operationId) {
        Proposal storage stored = _proposal(proposalId);
        if (stored.queued) revert RehearsalGovernorAlreadyQueued(proposalId);
        if (block.number <= stored.voteEndBlock) revert RehearsalGovernorVotingClosed(proposalId);
        if (stored.forVotes < quorumVotes) {
            revert RehearsalGovernorQuorumNotMet(proposalId, stored.forVotes, quorumVotes);
        }
        uint64 readyAt;
        (operationId, readyAt) =
            timelock.schedule(stored.target, stored.value, stored.data, proposalId);
        stored.queued = true;
        stored.queuedAt = uint64(block.timestamp);
        stored.readyAt = readyAt;
        emit RehearsalGovernorProposalQueued(proposalId, operationId, readyAt);
    }

    function execute(bytes32 proposalId) external returns (bytes memory returnData) {
        Proposal storage stored = _proposal(proposalId);
        if (!stored.queued) revert RehearsalGovernorNotQueued(proposalId);
        if (stored.executed) revert RehearsalGovernorAlreadyExecuted(proposalId);
        bytes memory result = timelock.execute{ value: stored.value }(
            stored.target, stored.value, stored.data, proposalId
        );
        stored.executed = true;
        stored.executedAt = uint64(block.timestamp);
        stored.returnData = result;
        emit RehearsalGovernorProposalExecuted(proposalId, result);
        return result;
    }

    function approveDigest(bytes32 digest) external onlyVoter {
        if (!digestApprovedBy[digest][msg.sender]) {
            digestApprovedBy[digest][msg.sender] = true;
            digestApprovalCount[digest] += 1;
        }
    }

    function isValidSignature(bytes32 digest, bytes calldata) external view returns (bytes4) {
        return
            digestApprovalCount[digest] >= quorumVotes
                ? _ERC1271_MAGIC_VALUE
                : _ERC1271_INVALID_VALUE;
    }

    function erc1271Posture() external pure returns (bytes32) {
        return keccak256("ERC1271_APPROVED_DIGEST_GOVERNOR_QUORUM");
    }

    function _proposal(bytes32 proposalId) private view returns (Proposal storage stored) {
        stored = _proposals[proposalId];
        if (stored.proposedAtBlock == 0) revert RehearsalGovernorUnknownProposal(proposalId);
    }

    receive() external payable {
        receivedNative += msg.value;
        lastNativeSender = msg.sender;
    }
}

/// @notice Mutable guarded scenario used by the real forwarding-cap probe. The
///         caller cannot shape the probe input; changing this threshold models a
///         guarded subsystem moving between healthy and degraded states.
contract StreamGovernanceV2RehearsalGasConsumer {
    uint256 public minimumGas;

    constructor(uint256 minimumGas_) {
        minimumGas = minimumGas_;
    }

    function setMinimumGas(uint256 minimumGas_) external {
        minimumGas = minimumGas_;
    }

    function guardedRead() external view returns (bytes32) {
        require(gasleft() >= minimumGas, "rehearsal guarded read under cap");
        return keccak256(abi.encode(address(this), minimumGas));
    }
}

/// @notice Local registry with the exact production read surface needed by the
///         production gas-parameter host. Registration pins live codehash and
///         nonzero manifest commitments; mutation exists only to exercise
///         execution-time binding drift in other focused tests.
struct StreamGovernanceV2RehearsalModuleRecordV2 {
    uint8 status;
    bytes32 moduleType;
    bytes32 moduleVersion;
    bytes4 interfaceId;
    uint32 moduleGasLimit;
    bytes32 runtimeCodeHash;
    bytes32 deploymentManifestHash;
    bytes32 moduleManifestHash;
    string moduleManifestURI;
    uint64 registeredAt;
    uint64 statusUpdatedAt;
    uint64 revision;
}

contract StreamGovernanceV2RehearsalModuleRegistry {
    bytes32 private constant _GGP_PROBE_MODULE_TYPE =
        0xe358a47f0dcbc7a22cc88ea7cd9ff433ec85ce6d9c7d0dc3f329e98b621cd6c8;
    bytes4 private constant _GGP_PROBE_INTERFACE_ID = 0x0f8c6b0f;

    mapping(address => StreamGovernanceV2RehearsalModuleRecordV2) private _records;
    address[] private _modules;

    function registerGasProbe(address probe) external {
        require(probe != address(0) && probe.code.length != 0, "invalid rehearsal probe");
        require(
            _records[probe].status == uint8(ModuleRegistryStatus.UNKNOWN),
            "probe already registered"
        );
        _modules.push(probe);
        _records[probe] = StreamGovernanceV2RehearsalModuleRecordV2({
            status: uint8(ModuleRegistryStatus.ACTIVE),
            moduleType: _GGP_PROBE_MODULE_TYPE,
            moduleVersion: keccak256("STREAM_GOVERNANCE_V2_REHEARSAL_PROBE_V1"),
            interfaceId: _GGP_PROBE_INTERFACE_ID,
            moduleGasLimit: 0,
            runtimeCodeHash: probe.codehash,
            deploymentManifestHash: keccak256(abi.encode("rehearsal-deployment", probe.codehash)),
            moduleManifestHash: keccak256(abi.encode("rehearsal-module", probe.codehash)),
            moduleManifestURI: "ipfs://local-governance-v2-holder-rehearsal",
            registeredAt: uint64(block.timestamp),
            statusUpdatedAt: uint64(block.timestamp),
            revision: 1
        });
    }

    function moduleRecord(address module)
        external
        view
        returns (StreamGovernanceV2RehearsalModuleRecordV2 memory)
    {
        return _records[module];
    }

    function isModuleEligible(
        address module,
        bytes32 expectedModuleType,
        bytes4 expectedInterfaceId
    ) external view returns (bool) {
        StreamGovernanceV2RehearsalModuleRecordV2 storage record = _records[module];
        return record.status == uint8(ModuleRegistryStatus.ACTIVE)
            && record.moduleType == expectedModuleType && record.interfaceId == expectedInterfaceId
            && record.runtimeCodeHash == module.codehash;
    }

    function moduleRegistryManifest()
        external
        pure
        returns (bytes32 manifestHash, string memory manifestURI, uint64 revision)
    {
        return (
            keccak256("STREAM_GOVERNANCE_V2_REHEARSAL_REGISTRY_V1"),
            "ipfs://local-governance-v2-holder-rehearsal-registry",
            1
        );
    }

    function moduleCount() external view returns (uint256) {
        return _modules.length;
    }

    function moduleAt(uint256 index) external view returns (address) {
        return _modules[index];
    }

    function registrationChainHash() external view returns (bytes32 chainHash, uint64 count) {
        return (keccak256(abi.encode(_modules)), uint64(_modules.length));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IStreamModuleRegistry).interfaceId || interfaceId == 0x01ffc9a7;
    }
}

contract StreamGovernanceV2RehearsalCorePointer {
    bytes32 private constant _MODULE_REGISTRY_POINTER_TYPE =
        0xde86dd5f33a5b2bd22cfbe7752609f5086a946f705768f7e2e6cb501157a41c4;

    address private immutable _registry;

    constructor(address registry_) {
        _registry = registry_;
    }

    function getSatellitePointer(bytes32 pointerType)
        external
        view
        returns (
            address target,
            bytes32 codeHash,
            bool frozen,
            bytes32 moduleType,
            bytes4 interfaceId,
            address registry,
            uint8 registryStatus,
            bytes32 moduleManifestHash,
            bytes32 deploymentManifestHash,
            uint64 revision
        )
    {
        if (pointerType != _MODULE_REGISTRY_POINTER_TYPE) {
            return (
                address(0),
                bytes32(0),
                false,
                bytes32(0),
                bytes4(0),
                address(0),
                0,
                bytes32(0),
                bytes32(0),
                0
            );
        }
        target = _registry;
        codeHash = _registry.codehash;
        moduleType = _MODULE_REGISTRY_POINTER_TYPE;
        interfaceId = type(IStreamModuleRegistry).interfaceId;
        registry = _registry;
        registryStatus = uint8(ModuleRegistryStatus.ACTIVE);
        moduleManifestHash = keccak256("rehearsal-registry-module-manifest");
        deploymentManifestHash = keccak256("rehearsal-registry-deployment-manifest");
        revision = 1;
    }
}
