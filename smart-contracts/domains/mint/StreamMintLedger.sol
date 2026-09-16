// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintLedger.sol";
import "../../interfaces/stream/mint/IStreamMintLedgerRevocation.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "./StreamMintCounterPolicy.sol";
import "./StreamMintImport.sol";

/// @notice Durable outside-Core accounting ledger for launch mint counters.
contract StreamMintLedger is
    IStreamMintLedger,
    IStreamMintLedgerRevocation,
    IStreamMintCounterPolicy,
    IStreamMintLedgerImport,
    Ownable,
    ERC165
{
    uint16 public constant SCHEMA_VERSION = 1;
    uint64 public constant MAX_POLICY_GRACE_SECONDS = 2_592_000;
    bytes32 public constant VALUE_KEY_DOMAIN = keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1");

    /// @notice Returns whether an address may register and consume ledger state.
    mapping(address => bool) public override ledgerWriter;
    /// @notice Returns the registered policy hash for a manager phase.
    mapping(address => mapping(uint256 => mapping(bytes32 => bytes32)))
        public
        override registeredPhasePolicyHash;
    mapping(
        address => mapping(uint256 => mapping(bytes32 => mapping(bytes32 => LedgerCounterPolicy)))
    ) private _registeredCounterPolicies;
    mapping(address => mapping(uint256 => mapping(bytes32 => mapping(bytes32 => uint256)))) private
        _registeredCounterPolicyVersions;
    mapping(address => mapping(uint256 => mapping(bytes32 => uint256))) private
        _counterPolicyVersion;
    mapping(address => mapping(uint256 => mapping(bytes32 => uint64))) private _phasePolicyRevision;
    mapping(address => mapping(uint256 => mapping(bytes32 => LedgerPolicyGrace))) private
        _policyGrace;
    /// @notice Returns the durable uint64 value for one ledger counter key.
    /// @dev Counter values are not reset by phase policy re-registration.
    mapping(bytes32 => uint64) public override counterValue;
    mapping(address => mapping(bytes32 => bool)) private _authorizationUsed;
    mapping(address => mapping(bytes32 => bool)) private _nullifierUsed;
    mapping(address => mapping(bytes32 => bool)) private _operationRootUsed;
    mapping(bytes32 => Definition) private _counterDefinitions;
    mapping(bytes32 => bool) private _definitionExists;
    // 0: unseen; 1: permanently legacy; 2: immutable registered definition.
    mapping(address => mapping(bytes32 => uint8)) private _definitionSelection;
    mapping(address => uint64) public override ledgerWriterRetiredAt;
    mapping(bytes32 => ImportCommitment) private _imports;
    mapping(address => bytes32) private _successorImportRoot;
    mapping(bytes32 => mapping(bytes32 => bool)) private _importedLeaves;
    mapping(address => bytes32[]) private _managerDefinitionHashes;
    mapping(bytes32 => uint256) private _importDefinitionCount;
    mapping(bytes32 => uint256) private _importDefinitionCursor;

    function registerCounterDefinition(Definition calldata definition)
        external
        override
        returns (bytes32 hash)
    {
        StreamMintCounterPolicy.validateDefinition(definition);
        hash = StreamMintCounterPolicy.definitionHash(definition);
        if (!_definitionExists[hash]) {
            _definitionExists[hash] = true;
            _counterDefinitions[hash] = definition;
            emit MintCounterDefinitionRegistered(
                hash,
                definition.scope,
                definition.keyMode,
                definition.capRoot,
                definition.metadataHash
            );
        }
    }

    function counterDefinition(bytes32 hash)
        external
        view
        override
        returns (bool, Definition memory)
    {
        return (_definitionExists[hash], _counterDefinitions[hash]);
    }

    function counterDefinitionForManager(address manager, bytes32 hash)
        public
        view
        override
        returns (bool, Definition memory d)
    {
        uint8 selected = _definitionSelection[manager][hash];
        bool exists = selected == 2 || (selected == 0 && _definitionExists[hash]);
        if (exists) d = _counterDefinitions[hash];
        else d.scope = CounterScope.PHASE;
        return (exists, d);
    }

    function managerDefinitionCount(address manager) external view override returns (uint256) {
        return _managerDefinitionHashes[manager].length;
    }

    function managerDefinitionAt(address manager, uint256 index)
        external
        view
        override
        returns (bytes32 hash, bool defined, Definition memory d)
    {
        hash = _managerDefinitionHashes[manager][index];
        (defined, d) = counterDefinitionForManager(manager, hash);
    }

    /// @notice Returns true for deployment validation.
    function isStreamMintLedger() external pure override returns (bool) {
        return true;
    }

    /// @notice Advertises the ledger interface required by Core satellite validation.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC165)
        returns (bool)
    {
        return interfaceId == type(IStreamMintLedger).interfaceId
            || interfaceId == type(IStreamMintLedgerRevocation).interfaceId
            || interfaceId == type(IStreamMintCounterPolicy).interfaceId
            || interfaceId == type(IStreamMintLedgerImport).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice Enables or disables an authorized ledger writer.
    function setLedgerWriter(address writer, bool allowed) external override onlyOwner {
        if (writer == address(0)) {
            revert InvalidLedgerWriter(writer);
        }
        if (allowed && (writer.code.length == 0 || ledgerWriterRetiredAt[writer] != 0)) {
            revert InvalidLedgerWriter(writer);
        }
        ledgerWriter[writer] = allowed;
        emit MintLedgerWriterUpdated(writer, allowed);
    }

    /// @notice Irreversibly stops this writer before a successor snapshot can be committed.
    function retireLedgerWriter(address writer) external override onlyOwner {
        if (
            writer.code.length == 0 || ledgerWriterRetiredAt[writer] != 0 || block.number == 0
                || block.number > type(uint64).max
        ) {
            revert MintImportInvalid();
        }
        bytes32 root = _successorImportRoot[writer];
        if (root != 0 && !_imports[root].complete) revert MintImportNotReady(writer);
        ledgerWriter[writer] = false;
        ledgerWriterRetiredAt[writer] = uint64(block.number);
        emit MintLedgerWriterUpdated(writer, false);
        emit MintLedgerWriterRetired(writer, uint64(block.number));
    }

    function commitCounterImportRoot(
        address predecessorLedger,
        address predecessorManager,
        address successorManager,
        uint64 snapshotBlock,
        bytes32 importRoot,
        bytes32 manifestHash
    ) external override onlyOwner {
        if (
            importRoot == 0 || manifestHash == 0 || predecessorLedger.code.length == 0
                || predecessorManager == successorManager || successorManager.code.length == 0
                || ledgerWriterRetiredAt[successorManager] != 0
                || _imports[importRoot].successorManager != address(0)
                || _successorImportRoot[successorManager] != 0 || snapshotBlock > block.number
        ) revert MintImportInvalid();
        uint64 retiredAt =
            IStreamMintLedgerImport(predecessorLedger).ledgerWriterRetiredAt(predecessorManager);
        if (
            retiredAt == 0 || snapshotBlock < retiredAt
                || IStreamMintLedger(predecessorLedger).ledgerWriter(predecessorManager)
        ) revert MintImportInvalid();
        StreamMintImport.requireManagerPair(
            predecessorLedger, predecessorManager, successorManager, owner()
        );
        ImportCommitment memory c = ImportCommitment(
            predecessorLedger,
            predecessorManager,
            successorManager,
            snapshotBlock,
            manifestHash,
            0,
            0,
            false
        );
        bytes32 actionId = StreamMintImport.authenticateCommit(owner(), c, importRoot);
        _imports[importRoot] = c;
        _successorImportRoot[successorManager] = importRoot;
        _importDefinitionCount[importRoot] =
            IStreamMintCounterPolicy(predecessorLedger).managerDefinitionCount(predecessorManager);
        emit MintLedgerImportRootCommitted(
            SCHEMA_VERSION,
            importRoot,
            predecessorManager,
            successorManager,
            predecessorLedger,
            snapshotBlock,
            manifestHash
        );
        emit MintLedgerImportAction(importRoot, actionId);
    }

    function mintImportCommitment(bytes32 root)
        external
        view
        override
        returns (ImportCommitment memory)
    {
        return _imports[root];
    }

    function isMintSuccessorReady(
        address predecessorLedger,
        address predecessorManager,
        address successorManager
    ) external view override returns (bool) {
        ImportCommitment storage c = _imports[_successorImportRoot[successorManager]];
        return c.complete && c.predecessorLedger == predecessorLedger
            && c.predecessorManager == predecessorManager && c.successorManager == successorManager
            && ledgerWriter[successorManager] && ledgerWriterRetiredAt[successorManager] == 0;
    }

    function importCounterValue(
        bytes32 root,
        CounterImportLeaf calldata leaf,
        bytes32 successorSubjectKey,
        bytes32[] calldata proof
    ) external override {
        ImportCommitment storage c = _requireImportWriter(root);
        bytes32 hash = StreamMintImport.counterLeaf(c, leaf);
        _requireImportProof(root, hash, proof);
        if (
            leaf.predecessorSubjectKey != StreamMintImport.subject(c.predecessorLedger, leaf)
                || successorSubjectKey != StreamMintImport.subject(address(this), leaf)
        ) revert MintImportInvalid();
        bytes32 predecessorKey = deriveCounterValueKey(
            c.predecessorManager,
            leaf.collectionId,
            leaf.phaseId,
            leaf.counterId,
            leaf.predecessorSubjectKey
        );
        if (IStreamMintLedger(c.predecessorLedger).counterValue(predecessorKey) != leaf.value) {
            revert MintImportInvalid();
        }
        bytes32 valueKey = deriveCounterValueKey(
            msg.sender, leaf.collectionId, leaf.phaseId, leaf.counterId, successorSubjectKey
        );
        _importedLeaves[root][hash] = true;
        c.importedCounters++;
        uint64 current = counterValue[valueKey];
        if (leaf.value > current) counterValue[valueKey] = leaf.value;
        emit MintLedgerCounterImported(
            SCHEMA_VERSION,
            root,
            valueKey,
            successorSubjectKey,
            leaf.collectionId,
            leaf.phaseId,
            leaf.counterId,
            leaf.value,
            counterValue[valueKey]
        );
    }

    function importNullifier(bytes32 root, bytes32 nullifier, bytes32[] calldata proof)
        external
        override
    {
        ImportCommitment storage c = _requireImportWriter(root);
        bytes32 hash = StreamMintImport.nullifierLeaf(c, nullifier);
        _requireImportProof(root, hash, proof);
        if (
            nullifier == 0
                || !IStreamMintLedger(c.predecessorLedger)
                    .isManagerNullifierUsed(c.predecessorManager, nullifier)
        ) revert MintImportInvalid();
        _importedLeaves[root][hash] = true;
        c.importedNullifiers++;
        _nullifierUsed[msg.sender][nullifier] = true;
        emit MintLedgerNullifierImported(SCHEMA_VERSION, root, nullifier, msg.sender);
    }

    function mintImportDefinitionProgress(bytes32 root)
        external
        view
        override
        returns (uint256 imported, uint256 required)
    {
        return (_importDefinitionCursor[root], _importDefinitionCount[root]);
    }

    function importCounterDefinitions(bytes32 root, uint256 maxCount) external override {
        ImportCommitment storage c = _imports[root];
        if (
            c.successorManager == address(0) || c.complete
                || ledgerWriterRetiredAt[c.successorManager] != 0 || maxCount == 0 || maxCount > 32
        ) revert MintImportInvalid();
        uint256 cursor = _importDefinitionCursor[root];
        uint256 end = cursor + maxCount;
        if (end > _importDefinitionCount[root]) end = _importDefinitionCount[root];
        for (; cursor < end; ++cursor) {
            (bytes32 hash, bool defined, Definition memory d) = IStreamMintCounterPolicy(
                    c.predecessorLedger
                ).managerDefinitionAt(c.predecessorManager, cursor);
            uint8 selection = defined ? 2 : 1;
            uint8 existing = _definitionSelection[c.successorManager][hash];
            if (existing != 0 && existing != selection) revert MintImportInvalid();
            if (defined) {
                StreamMintCounterPolicy.validateDefinition(d);
                if (StreamMintCounterPolicy.definitionHash(d) != hash) revert MintImportInvalid();
                if (!_definitionExists[hash]) {
                    _definitionExists[hash] = true;
                    _counterDefinitions[hash] = d;
                    emit MintCounterDefinitionRegistered(
                        hash, d.scope, d.keyMode, d.capRoot, d.metadataHash
                    );
                }
            }
            if (existing == 0) {
                _definitionSelection[c.successorManager][hash] = selection;
                _managerDefinitionHashes[c.successorManager].push(hash);
            }
            emit MintLedgerImportProfileCopied(root, hash, defined);
        }
        _importDefinitionCursor[root] = cursor;
    }

    function completeCounterImport(
        bytes32 root,
        uint64 counterLeaves,
        uint64 nullifierLeaves,
        bytes32[] calldata descriptorProof
    ) external override {
        ImportCommitment storage c = _imports[root];
        if (
            c.successorManager == address(0) || c.complete || c.importedCounters != counterLeaves
                || c.importedNullifiers != nullifierLeaves
                || _importDefinitionCursor[root] != _importDefinitionCount[root]
        ) revert MintImportInvalid();
        bytes32 descriptor = StreamMintImport.descriptorLeaf(c, counterLeaves, nullifierLeaves);
        if (!StreamMintCounterPolicy.verify(root, descriptor, descriptorProof)) {
            revert MintImportProofInvalid(descriptor);
        }
        c.complete = true;
        emit MintLedgerImportCompleted(root, c.successorManager, counterLeaves, nullifierLeaves);
    }

    function _requireImportWriter(bytes32 root) private view returns (ImportCommitment storage c) {
        _requireLedgerWriter();
        c = _imports[root];
        if (c.successorManager != msg.sender || c.complete) revert MintImportInvalid();
    }

    function _requireImportProof(bytes32 root, bytes32 hash, bytes32[] calldata proof)
        private
        view
    {
        if (_importedLeaves[root][hash]) revert MintImportLeafAlreadyUsed(hash);
        if (!StreamMintCounterPolicy.verify(root, hash, proof)) {
            revert MintImportProofInvalid(hash);
        }
    }

    /// @notice Permanently voids one authorization in this authorized manager's existing replay map.
    function voidAuthorization(address manager, bytes32 authorizationId) external override {
        _requireLedgerWriter();
        if (manager != msg.sender) revert InvalidAuthorizationManager(manager, msg.sender);
        if (authorizationId == bytes32(0)) revert InvalidAuthorizationId(authorizationId);
        if (_authorizationUsed[msg.sender][authorizationId]) {
            revert AuthorizationAlreadyConsumed(authorizationId);
        }
        _authorizationUsed[msg.sender][authorizationId] = true;
        emit MintLedgerAuthorizationVoided(SCHEMA_VERSION, authorizationId, msg.sender);
    }

    /// @notice Registers the active static launch policy for a manager phase.
    function registerPhasePolicy(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash,
        bytes32[] calldata counterIds,
        LedgerCounterPolicy[] calldata counterPolicies,
        uint64 graceUntil
    ) external override {
        _requireLedgerWriter();
        _requirePhasePolicy(manager, collectionId, phaseId, policyHash);
        if (manager != msg.sender) {
            revert InvalidPhasePolicy(manager, collectionId, phaseId);
        }
        if (counterIds.length != counterPolicies.length) {
            revert CounterPolicyLengthMismatch(counterIds.length, counterPolicies.length);
        }

        bytes32 previousPolicyHash = registeredPhasePolicyHash[manager][collectionId][phaseId];
        uint64 previousRevision = _phasePolicyRevision[manager][collectionId][phaseId];
        uint64 activeRevision = previousRevision;
        uint256 activeCounterVersion = _counterPolicyVersion[manager][collectionId][phaseId] + 1;
        _counterPolicyVersion[manager][collectionId][phaseId] = activeCounterVersion;
        if (previousPolicyHash != policyHash) {
            if (activeRevision == type(uint64).max) {
                revert InvalidPhasePolicy(manager, collectionId, phaseId);
            }
            activeRevision++;
            if (previousPolicyHash == bytes32(0)) {
                if (graceUntil != 0) {
                    revert InvalidPolicyGrace(graceUntil);
                }
            } else {
                _setPolicyGrace(
                    manager,
                    collectionId,
                    phaseId,
                    previousPolicyHash,
                    previousRevision,
                    policyHash,
                    graceUntil
                );
            }
        } else if (graceUntil != 0) {
            revert InvalidPolicyGrace(graceUntil);
        }
        _phasePolicyRevision[manager][collectionId][phaseId] = activeRevision;
        registeredPhasePolicyHash[manager][collectionId][phaseId] = policyHash;
        emit MintLedgerPhasePolicyRegistered(manager, collectionId, phaseId, policyHash);

        for (uint256 i = 0; i < counterIds.length; i++) {
            _registerCounterPolicy(
                manager,
                collectionId,
                phaseId,
                policyHash,
                activeCounterVersion,
                counterIds,
                counterPolicies,
                i
            );
        }
    }

    /// @notice Consumes one manager-scoped operation root and its accounting facts.
    function consume(
        uint256 collectionId,
        bytes32 phaseId,
        CounterConsumption[] calldata consumptions,
        bytes32 authorizationId,
        bytes32[] calldata nullifiers,
        bytes32 boundPolicyHash,
        bytes32 operationRoot
    ) external override {
        _requireLedgerWriter();
        bytes32 currentPolicyHash = registeredPhasePolicyHash[msg.sender][collectionId][phaseId];
        bytes32 importRoot = _successorImportRoot[msg.sender];
        if (importRoot != 0 && !_imports[importRoot].complete) {
            revert MintImportNotReady(msg.sender);
        }
        _requireBoundPolicy(msg.sender, collectionId, phaseId, currentPolicyHash, boundPolicyHash);
        _requireOperationRoot(operationRoot);

        bool hasAuthorization = authorizationId != bytes32(0);
        if (hasAuthorization && _authorizationUsed[msg.sender][authorizationId]) {
            revert AuthorizationAlreadyConsumed(authorizationId);
        }
        _requireUnusedNullifiers(nullifiers);

        for (uint256 i = 0; i < consumptions.length; i++) {
            CounterConsumption calldata consumption = consumptions[i];
            if (consumption.collectionId != collectionId || consumption.phaseId != phaseId) {
                revert InvalidPhasePolicy(msg.sender, collectionId, phaseId);
            }
            _consumeCounter(consumption, boundPolicyHash, operationRoot);
        }

        _operationRootUsed[msg.sender][operationRoot] = true;
        if (hasAuthorization) {
            _authorizationUsed[msg.sender][authorizationId] = true;
            emit MintLedgerAuthorizationConsumed(
                SCHEMA_VERSION, authorizationId, operationRoot, msg.sender, boundPolicyHash
            );
        }
        for (uint256 i = 0; i < nullifiers.length; i++) {
            bytes32 nullifier = nullifiers[i];
            _nullifierUsed[msg.sender][nullifier] = true;
            emit MintLedgerNullifierConsumed(
                SCHEMA_VERSION, nullifier, operationRoot, msg.sender, boundPolicyHash
            );
        }
        emit MintLedgerOperationRootConsumed(
            SCHEMA_VERSION,
            operationRoot,
            msg.sender,
            currentPolicyHash,
            boundPolicyHash,
            authorizationId
        );
    }

    /// @notice Returns the registered static policy for one counter.
    function registeredCounterPolicy(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId
    ) external view override returns (LedgerCounterPolicy memory) {
        uint256 activeVersion = _counterPolicyVersion[manager][collectionId][phaseId];
        if (
            activeVersion == 0
                || _registeredCounterPolicyVersions[manager][collectionId][phaseId][counterId]
                    != activeVersion
        ) {
            return LedgerCounterPolicy({
                enabled: false,
                capMode: CounterCapMode.NONE,
                deltaMode: CounterDeltaMode.STATIC,
                staticCap: 0,
                staticIncrement: 0,
                counterConfigHash: bytes32(0)
            });
        }
        return _registeredCounterPolicies[manager][collectionId][phaseId][counterId];
    }

    /// @notice Returns whether a manager has already consumed an authorization ID.
    function isManagerAuthorizationUsed(address manager, bytes32 authorizationId)
        external
        view
        override
        returns (bool)
    {
        return _authorizationUsed[manager][authorizationId];
    }

    /// @notice Returns whether a manager has already consumed a nullifier.
    function isManagerNullifierUsed(address manager, bytes32 nullifier)
        external
        view
        override
        returns (bool)
    {
        return _nullifierUsed[manager][nullifier];
    }

    /// @notice Returns whether a manager has already consumed an operation root.
    function isManagerOperationRootUsed(address manager, bytes32 operationRoot)
        external
        view
        override
        returns (bool)
    {
        return _operationRootUsed[manager][operationRoot];
    }

    /// @notice Returns the immediate predecessor grace tuple for a manager phase.
    function policyGrace(address manager, uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (
            bytes32 previousPolicyHash,
            uint64 previousPolicyRevision,
            uint64 previousPolicyGraceUntil
        )
    {
        LedgerPolicyGrace memory grace = _policyGrace[manager][collectionId][phaseId];
        return
            (grace.previousPolicyHash, grace.previousPolicyRevision, grace.previousPolicyGraceUntil);
    }

    /// @notice Derives the canonical value key for a manager counter subject.
    function deriveCounterValueKey(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        bytes32 subjectKey
    ) public pure override returns (bytes32) {
        return keccak256(
            abi.encode(VALUE_KEY_DOMAIN, manager, collectionId, phaseId, counterId, subjectKey)
        );
    }

    function _setPolicyGrace(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 previousPolicyHash,
        uint64 previousRevision,
        bytes32 newPolicyHash,
        uint64 graceUntil
    ) private {
        if (previousPolicyHash == bytes32(0)) {
            if (graceUntil != 0) {
                revert InvalidPolicyGrace(graceUntil);
            }
            delete _policyGrace[manager][collectionId][phaseId];
        } else if (graceUntil == 0) {
            delete _policyGrace[manager][collectionId][phaseId];
        } else {
            if (graceUntil > block.timestamp + MAX_POLICY_GRACE_SECONDS) {
                revert InvalidPolicyGrace(graceUntil);
            }
            _policyGrace[manager][collectionId][phaseId] = LedgerPolicyGrace({
                previousPolicyHash: previousPolicyHash,
                previousPolicyRevision: previousRevision,
                previousPolicyGraceUntil: graceUntil
            });
        }
        emit MintLedgerPolicyGraceSet(
            SCHEMA_VERSION,
            collectionId,
            phaseId,
            manager,
            previousPolicyHash,
            newPolicyHash,
            graceUntil
        );
    }

    function _requireBoundPolicy(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 currentPolicyHash,
        bytes32 boundPolicyHash
    ) private view {
        if (currentPolicyHash == bytes32(0) || boundPolicyHash == bytes32(0)) {
            revert InvalidPhasePolicy(manager, collectionId, phaseId);
        }
        if (boundPolicyHash == currentPolicyHash) {
            return;
        }
        LedgerPolicyGrace memory grace = _policyGrace[manager][collectionId][phaseId];
        uint64 currentRevision = _phasePolicyRevision[manager][collectionId][phaseId];
        if (
            grace.previousPolicyHash != boundPolicyHash
                || grace.previousPolicyRevision + 1 != currentRevision
                || block.timestamp > grace.previousPolicyGraceUntil
        ) {
            revert InvalidPhasePolicy(manager, collectionId, phaseId);
        }
    }

    function _requireOperationRoot(bytes32 operationRoot) private view {
        if (operationRoot == bytes32(0)) {
            revert OperationRootRequired();
        }
        if (_operationRootUsed[msg.sender][operationRoot]) {
            revert OperationRootAlreadyConsumed(msg.sender, operationRoot);
        }
    }

    function _requireUnusedNullifiers(bytes32[] calldata nullifiers) private view {
        for (uint256 i = 0; i < nullifiers.length; i++) {
            bytes32 nullifier = nullifiers[i];
            if (nullifier == bytes32(0) || _nullifierUsed[msg.sender][nullifier]) {
                revert NullifierAlreadyConsumed(nullifier);
            }
            for (uint256 j = 0; j < i; j++) {
                if (nullifiers[j] == nullifier) {
                    revert NullifierAlreadyConsumed(nullifier);
                }
            }
        }
    }

    function _requireLedgerWriter() private view {
        if (!ledgerWriter[msg.sender]) {
            revert UnauthorizedLedgerWriter(msg.sender);
        }
    }

    function _requirePhasePolicy(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash
    ) private view {
        if (
            manager == address(0) || manager != msg.sender || collectionId == 0
                || phaseId == bytes32(0) || policyHash == bytes32(0)
        ) {
            revert InvalidPhasePolicy(manager, collectionId, phaseId);
        }
    }

    function _registerCounterPolicy(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash,
        uint256 activeVersion,
        bytes32[] calldata counterIds,
        LedgerCounterPolicy[] calldata counterPolicies,
        uint256 index
    ) private {
        bytes32 counterId = counterIds[index];
        _requireNoDuplicateCounterId(counterIds, index, counterId);
        LedgerCounterPolicy calldata policy = counterPolicies[index];
        _requireStaticCounterPolicy(counterId, policy);
        bytes32 definitionId = policy.counterConfigHash;
        if (_definitionSelection[manager][definitionId] == 0) {
            _definitionSelection[manager][definitionId] = _definitionExists[definitionId] ? 2 : 1;
            _managerDefinitionHashes[manager].push(definitionId);
        }
        (bool defined, Definition memory definition) =
            counterDefinitionForManager(manager, definitionId);
        if (
            (policy.capMode == CounterCapMode.MERKLE_STATIC
                    && (!defined || definition.capRoot == bytes32(0) || policy.staticCap == 0))
                || (defined
                    && (policy.capMode == CounterCapMode.NONE
                        || (definition.capRoot != bytes32(0)
                            && policy.capMode != CounterCapMode.MERKLE_STATIC)))
        ) {
            revert InvalidCounterPolicy(counterId);
        }
        _registeredCounterPolicies[manager][collectionId][phaseId][counterId] = policy;
        _registeredCounterPolicyVersions[manager][collectionId][phaseId][counterId] = activeVersion;
        _emitCounterPolicyRegistered(manager, collectionId, phaseId, counterId, policy, policyHash);
    }

    function _emitCounterPolicyRegistered(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        LedgerCounterPolicy calldata policy,
        bytes32 policyHash
    ) private {
        emit MintLedgerCounterPolicyRegistered(
            manager,
            collectionId,
            phaseId,
            counterId,
            policy.capMode,
            policy.deltaMode,
            policy.staticCap,
            policy.staticIncrement,
            policy.counterConfigHash,
            policyHash
        );
    }

    function _requireNoDuplicateCounterId(
        bytes32[] calldata counterIds,
        uint256 index,
        bytes32 counterId
    ) private pure {
        if (counterId == bytes32(0)) {
            revert InvalidCounterPolicy(counterId);
        }
        for (uint256 j = 0; j < index; j++) {
            if (counterIds[j] == counterId) {
                revert DuplicateCounterPolicy(counterId);
            }
        }
    }

    function _requireStaticCounterPolicy(bytes32 counterId, LedgerCounterPolicy calldata policy)
        private
        pure
    {
        if (
            !policy.enabled || policy.deltaMode != CounterDeltaMode.STATIC
                || policy.capMode == CounterCapMode.RESOLVER || policy.staticIncrement == 0
                || policy.counterConfigHash == bytes32(0)
        ) {
            revert InvalidCounterPolicy(counterId);
        }
        if (policy.capMode == CounterCapMode.STATIC && policy.staticCap == 0) {
            revert InvalidCounterPolicy(counterId);
        }
        if (policy.capMode == CounterCapMode.NONE && policy.staticCap != 0) {
            revert InvalidCounterPolicy(counterId);
        }
    }

    function _consumeCounter(
        CounterConsumption calldata consumption,
        bytes32 boundPolicyHash,
        bytes32 operationRoot
    ) private {
        LedgerCounterPolicy memory policy = _registeredCounterPolicies[
            msg.sender
        ][consumption.collectionId][consumption.phaseId][consumption.counterId];
        if (
            !policy.enabled
                || _registeredCounterPolicyVersions[
                        msg.sender
                    ][consumption.collectionId][consumption.phaseId][consumption.counterId]
                    != _counterPolicyVersion[
                        msg.sender
                    ][consumption.collectionId][consumption.phaseId]
        ) {
            revert CounterPolicyNotRegistered(
                msg.sender, consumption.collectionId, consumption.phaseId, consumption.counterId
            );
        }
        if (
            consumption.valueKey == bytes32(0) || consumption.counterId == bytes32(0)
                || consumption.subjectKey == bytes32(0)
                || consumption.increment != policy.staticIncrement
                || policy.deltaMode != CounterDeltaMode.STATIC
                || policy.capMode == CounterCapMode.RESOLVER
        ) {
            revert CounterPolicyMismatch(consumption.counterId);
        }
        (, Definition memory definition) =
            counterDefinitionForManager(msg.sender, policy.counterConfigHash);
        (uint256 scopeCollection, bytes32 scopePhase) = StreamMintCounterPolicy.scopeIds(
            definition.scope, consumption.collectionId, consumption.phaseId
        );
        bytes32 expectedValueKey = deriveCounterValueKey(
            msg.sender, scopeCollection, scopePhase, consumption.counterId, consumption.subjectKey
        );
        if (consumption.valueKey != expectedValueKey) {
            revert CounterValueKeyMismatch(consumption.valueKey, expectedValueKey);
        }
        if (policy.capMode == CounterCapMode.STATIC && consumption.cap != policy.staticCap) {
            revert CounterPolicyMismatch(consumption.counterId);
        }
        if (policy.capMode == CounterCapMode.NONE && consumption.cap != 0) {
            revert CounterPolicyMismatch(consumption.counterId);
        }
        if (
            policy.capMode == CounterCapMode.MERKLE_STATIC
                && (consumption.cap == 0 || consumption.cap > policy.staticCap)
        ) {
            revert CounterPolicyMismatch(consumption.counterId);
        }

        uint64 currentValue = counterValue[consumption.valueKey];
        if (type(uint64).max - currentValue < consumption.increment) {
            revert CounterValueOverflow(consumption.valueKey);
        }
        uint64 newValue = currentValue + consumption.increment;
        if (policy.capMode != CounterCapMode.NONE && newValue > consumption.cap) {
            revert CounterCapExceeded(consumption.valueKey, newValue, consumption.cap);
        }
        counterValue[consumption.valueKey] = newValue;
        _emitCounterConsumed(consumption, newValue, boundPolicyHash, operationRoot);
    }

    function _emitCounterConsumed(
        CounterConsumption calldata consumption,
        uint64 newValue,
        bytes32 boundPolicyHash,
        bytes32 operationRoot
    ) private {
        emit MintLedgerCounterConsumed(
            SCHEMA_VERSION,
            consumption.valueKey,
            consumption.collectionId,
            consumption.phaseId,
            msg.sender,
            consumption.counterId,
            consumption.subjectKey,
            consumption.increment,
            newValue,
            consumption.cap,
            boundPolicyHash,
            operationRoot
        );
        emit MintLedgerCounterConsumptionContext(
            SCHEMA_VERSION,
            consumption.valueKey,
            consumption.counterId,
            consumption.subjectKey,
            msg.sender,
            consumption.payer,
            consumption.recipient,
            consumption.authorizer,
            consumption.executor,
            consumption.contextHash,
            consumption.resolutionHash
        );
    }
}
