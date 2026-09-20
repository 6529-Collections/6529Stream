// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamMintFallbackFixture.sol";

/// @dev Deliberately nonconforming test-only Manager. Its governed owner can leave a real
/// preparation outstanding; ordinary production Managers never expose this separate hook.
contract CurrentFallbackStrandingManager is StreamMintManager {
    constructor(IStreamCore core_, IStreamMintLedger ledger_, IERC165 registry_)
        StreamMintManager(core_, ledger_, registry_)
    { }

    function strandPreparedMint(bytes32 operation) external onlyOwner nonReentrant {
        bytes memory data = bytes("original incident preparation");
        core.prepareMintFromManager(1, data, keccak256(data), operation);
    }
}

/// @notice Real threshold-two Safe, executor, Registry, Manifest, Core, Artist and shared Ledger.
/// @dev Only the stranding Manager, lifetime gate and external entropy provider are test seams.
/// Native execution remains pending the coordinator's matched-source validation.
contract StreamCurrentMintFallbackIncidentTest is StreamMintFallbackFixture {
    bytes32 private constant INCIDENT_OPERATION = keccak256("durable actual preparation operation");
    StreamMintManagerFallback private rescue;
    CurrentContinuityEntitlementGate private rescueGate;
    bytes32 private historicState;

    function _deployReserveManager() internal override returns (StreamMintManager) {
        return StreamMintManager(
            _artistArtifactCreate(
                "test/current/StreamCurrentMintFallbackIncident.t.sol:CurrentFallbackStrandingManager",
                abi.encode(core, ledger, IERC165(address(registry)))
            )
        );
    }

    function _deployAdditionalProducts() internal override {
        super._deployAdditionalProducts();
        rescue = StreamMintManagerFallback(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamMintManagerFallback.sol:StreamMintManagerFallback",
                abi.encode(core, ledger, IERC165(address(registry)))
            )
        );
        ledger.setLedgerWriter(address(rescue), true);
        rescue.transferOwnership(address(executor));
        rescueGate = new CurrentContinuityEntitlementGate(
            address(core), address(successor), address(rescue), CONTINUITY_PHASE
        );
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        GovernanceActionPolicyEntry[] memory original = super._additionalOperatingPolicies();
        rows = new GovernanceActionPolicyEntry[](original.length + 6);
        for (uint256 i; i < original.length; ++i) {
            rows[i] = original[i];
        }
        uint256 n = original.length;
        rows[n++] = _fallbackPolicy(address(rescue), rescue.importMintState.selector);
        rows[n++] = _fallbackPolicy(address(rescue), rescue.configurePhase.selector);
        rows[n++] = _fallbackPolicy(address(rescue), rescue.setPhaseExecutor.selector);
        rows[n++] = _fallbackPolicy(address(rescue), rescue.raiseGasParameter.selector);
        rows[n++] = _fallbackPolicy(
            address(successor), CurrentFallbackStrandingManager.strandPreparedMint.selector
        );
        rows[n] = _fallbackPolicy(address(rescue), rescue.recoverPreparedMint.selector);
        rows[n].actionClass = 3;
    }

    function _handoffManager() internal override {
        super._handoffManager();
        StreamMintFallbackPlan.Configuration memory c = reserve;
        c.fallbackManager = rescue;
        c.fallbackCodeHash = address(rescue).codehash;
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        records[0] = StreamMintFallbackPlan.fallbackRegistration(c);
        records[1] = StreamModuleRegistration(
            address(rescueGate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            MODULE_VERSION,
            type(IStreamMintGate).interfaceId,
            300_000,
            address(rescueGate).codehash,
            DEPLOYMENT_HASH,
            GATE_MANIFEST,
            "urn:stream:fixture:lifetime-entitlement"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(1));
        bytes memory result = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    calls,
                    scope,
                    oldHash,
                    newHash,
                    ready,
                    ready + 7 days,
                    keccak256("genesis incident recovery reserve"),
                    "urn:stream:fixture:incident-recovery-reserve",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(result, (bytes32)), calls, data);
        StreamMintFallbackPlan.requireReserveReady(c);
    }

    function testActualSafeIncidentRecoveryAfterTwoRealImportsPreservesBurnAndAllocationGap()
        public
    {
        _setupFallback();
        require(continuitySafe.getThreshold() == 2, "actual threshold-two governor");
        uint64 rescueAdmitted = registry.moduleRecord(address(rescue)).registeredAt;
        require(rescueAdmitted < block.timestamp, "rescue admitted before operating exposure");
        _activateFallback();
        bytes32 firstRoot = tree[0];
        require(ledger.mintImportCommitment(firstRoot).complete, "first real import completed");
        vm.prank(BUYER);
        core.burn(2);
        historicState = _historicState();
        _ordinary(
            address(successor),
            abi.encodeCall(CurrentFallbackStrandingManager.strandPreparedMint, (INCIDENT_OPERATION))
        );
        _assertStranded();

        // Rotate the planning pair only after the first genuine cutover. Artist stays original.
        manager = successor;
        successor = rescue;
        require(
            gate.claimNullifier(CLAIM) == rescueGate.claimNullifier(CLAIM), "same lifetime claim"
        );
        gate = rescueGate;
        reserve = _reserveConfiguration();
        reserveActivatedAt = rescueAdmitted;
        _recoverThroughSafe();
        require(
            tree[0] != firstRoot && ledger.mintImportCommitment(firstRoot).complete
                && ledger.mintImportCommitment(tree[0]).complete
                && ledger.isCompletedMintDescendant(
                    address(ledger), originalArtistManager, address(rescue)
                ),
            "two genuine roots retain the original Artist lineage"
        );
        _assertRecovered();
        _assertHistoryAndCounters(false);
        _configureSuccessorWithFreshConsent();
        _mintAfterRecovery();
        _assertHistoryAndCounters(true);
    }

    function _recoverThroughSafe() private {
        StreamMintFallbackPlan.requireReserveReady(reserve);
        uint256 catalogCount = registry.moduleCount();
        bytes32 ledgerPointer =
            keccak256(abi.encode(StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER)));
        _revokePrimary();
        uint256 observed = block.timestamp;
        require(reserveActivatedAt < observed, "standing rescue predates incident");
        _retireAndSnapshot();
        (GovernanceCall[] memory imports, bytes[] memory importData) = _importPlan();
        (bytes32 importAction, uint64 importReady) =
            _scheduleBatchAsGovernor(1, imports, importData);
        (GovernanceCall[] memory calls, bytes[] memory data) =
            _activationPlan(3, INCIDENT_OPERATION);
        _assertRecoveryIntent(calls[1]);
        require(
            calls.length == 3 && calls[0].target == address(core)
                && calls[1].target == address(rescue) && calls[2].target == address(manifest),
            "exact pointer then recovery then manifest order"
        );
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(3, calls, data);
        require(
            block.timestamp <= observed + 4 hours && ready == observed + executor.minimumDelay(3)
                && ready == importReady,
            "Safe schedules within SLA and both ordinary delays elapse together"
        );
        vm.warp(ready);
        uint256 nonce = continuitySafe.nonce();
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            continuitySafe.nonce() == nonce
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED
                && StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target
                    == address(manager),
            "incomplete import rolls back actual Safe envelope and pointer"
        );
        _assertStranded();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (importAction, imports, importData))
        );
        _assertImported();
        _assertStranded();
        vm.recordLogs();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        _assertRecoveryEvent(vm.getRecordedLogs(), action);
        require(
            continuitySafe.nonce() == nonce + 2
                && executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED
                && registry.moduleCount() == catalogCount && block.timestamp == ready,
            "same threshold Safe executes both real batches at earliest permitted time"
        );
        require(
            StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target == address(rescue)
                && keccak256(abi.encode(StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER)))
                    == ledgerPointer,
            "rescue replaces Manager while canonical Ledger pointer is unchanged"
        );
        StreamSystemManifest.AggregateState memory aggregate =
            StreamGenesisManifestPlan.readAggregate(manifest);
        require(
            aggregate.modules.mintManager == address(rescue)
                && aggregate.modules.mintLedger == address(ledger),
            "actual manifest tail commits recovered selection"
        );
        require(
            ledger.ledgerWriterRetiredAt(originalArtistManager) != 0
                && ledger.ledgerWriterRetiredAt(address(manager)) != 0
                && !ledger.ledgerWriter(originalArtistManager)
                && !ledger.ledgerWriter(address(manager)),
            "both predecessor writer retirements remain permanent"
        );
    }

    function _assertRecoveryIntent(GovernanceCall memory call_) private view {
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_FALLBACK_RECOVERY_SCOPE_V1"),
                block.chainid,
                address(core),
                address(rescue),
                uint256(3),
                INCIDENT_OPERATION
            )
        );
        bytes32 retained = keccak256(
            abi.encode(uint256(1), uint256(3), uint256(3), uint256(4), uint256(2), uint256(1))
        );
        bytes32 domain = keccak256("6529STREAM_MINT_FALLBACK_RECOVERY_STATE_V1");
        require(
            call_.scopeHash == scope
                && call_.oldValueHash
                    == keccak256(
                        abi.encode(
                            domain,
                            scope,
                            true,
                            retained,
                            keccak256(core.tokenData(3)),
                            core.coordinatorAtMint(3)
                        )
                    )
                && call_.newValueHash
                    == keccak256(
                        abi.encode(domain, scope, false, retained, keccak256(bytes("")), address(0))
                    ),
            "independent token and operation intent in actual per-call class3 context"
        );
    }

    function _assertRecoveryEvent(Vm.Log[] memory logs, bytes32 action) private view {
        bytes32 topic =
            keccak256("MintFallbackPreparedRecovered(uint16,bytes32,uint256,bytes32,uint256)");
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(rescue) && logs[i].topics[0] == topic) {
                ++count;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == action
                        && logs[i].topics[2] == bytes32(uint256(3))
                        && logs[i].topics[3] == INCIDENT_OPERATION
                        && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), uint256(1))),
                    "one exact recovery receipt in actual governed batch"
                );
            }
        }
        require(count == 1, "exactly one recovery receipt");
    }

    function _assertStranded() private view {
        StreamPreparedMintRecord memory p = core.preparedMint(3);
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(3);
        require(
            p.exists && p.operationId == INCIDENT_OPERATION && p.collectionId == 1
                && core.pendingPreparedMintTokenId() == 3 && exists && collection == 1
                && serial == 3 && !burned && core.lastAllocatedTokenId() == 3
                && core.collectionNextSerial(1) == 4 && core.collectionMintedEver(1) == 2
                && core.totalSupply() == 1
                && keccak256(core.tokenData(3)) == keccak256(bytes("original incident preparation"))
                && _historicState() == historicState,
            "actual preparation persists without changing completed or burned history"
        );
    }

    function _assertRecovered() private view {
        StreamPreparedMintRecord memory p = core.preparedMint(3);
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(3);
        require(
            !p.exists && p.operationId == 0 && p.collectionId == 0
                && core.pendingPreparedMintTokenId() == 0 && !exists && collection == 0
                && serial == 0 && !burned && core.tokenData(3).length == 0
                && core.coordinatorAtMint(3) == address(0) && core.lastAllocatedTokenId() == 3
                && core.collectionNextSerial(1) == 4 && core.collectionMintedEver(1) == 2
                && core.totalSupply() == 1,
            "recovery clears exact liability while permanently retaining token3 and serial3 gap"
        );
    }

    function _historicState() private view returns (bytes32) {
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(2);
        require(
            exists && collection == 1 && serial == 2 && burned,
            "real previously completed burn retained"
        );
        return keccak256(
            abi.encode(
                core.ownerOf(1),
                core.tokenData(1),
                core.coordinatorAtMint(1),
                core.tokenData(2),
                core.coordinatorAtMint(2),
                wallet.balance,
                ledger.isManagerOperationRootUsed(originalArtistManager, paidOperation),
                ledger.isManagerAuthorizationUsed(originalArtistManager, originalAuthorization),
                ledger.isManagerOperationRootUsed(originalArtistManager, originalOperation)
            )
        );
    }

    function _assertHistoryAndCounters(bool freshMinted) private view {
        require(
            _historicState() == historicState && core.ownerOf(1) == BUYER
                && wallet.balance == 0.01 ether
                && StreamMintManager(originalArtistManager).nextOperationNonce() == 2
                && manager.nextOperationNonce() == 0
                && successor.nextOperationNonce() == (freshMinted ? 1 : 0),
            "original payments, receipts, completed burn and all Manager operation nonces survive"
        );
        for (uint256 i; i < leaves.length; ++i) {
            require(
                _value(ledger, StreamMintManager(originalArtistManager), leaves[i]) == 1
                    && _value(ledger, manager, leaves[i]) == 1
                    && _value(ledger, successor, leaves[i]) == (freshMinted && i != 0 ? 2 : 1),
                "both real imports preserve floors and only fresh rescue consumption increments"
            );
        }
        require(
            ledger.isManagerNullifierUsed(originalArtistManager, gate.claimNullifier(CLAIM))
                && ledger.isManagerNullifierUsed(address(manager), gate.claimNullifier(CLAIM))
                && ledger.isManagerNullifierUsed(address(rescue), gate.claimNullifier(CLAIM)),
            "same spent entitlement survives all three real Manager namespaces"
        );
    }

    function _mintAfterRecovery() private {
        preparedExecution = true;
        (IStreamMintManager.MintBatch memory spent, bytes memory spentData) =
            _mintRequest(successor, CLAIM, keccak256("twice imported spent claim"));
        uint256 nonce = continuitySafe.nonce();
        (bool ok,) = address(continuitySafe).call(_signedSuccessorCall(spent, spentData));
        require(
            !ok && continuitySafe.nonce() == nonce
                && !ledger.isManagerAuthorizationUsed(address(rescue), spent.authorizationId),
            "freshly authorized replay fails against actual twice-imported lifetime nullifier"
        );
        _assertRecovered();
        bytes32 claim = keccak256("fresh production rescue claim");
        (IStreamMintManager.MintBatch memory fresh, bytes memory data) =
            _mintRequest(successor, claim, keccak256("fresh production rescue nonce"));
        (ok,) = address(continuitySafe).call(_signedSuccessorCall(fresh, data));
        require(
            ok && continuitySafe.nonce() == nonce + 1, "actual Safe mints through production rescue"
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(4);
        require(
            exists && collection == 1 && serial == 4 && !burned && core.ownerOf(4) == BUYER
                && core.lastAllocatedTokenId() == 4 && core.collectionNextSerial(1) == 5
                && core.collectionMintedEver(1) == 3 && core.totalSupply() == 2
                && core.pendingPreparedMintTokenId() == 0 && !core.preparedMint(4).exists
                && !core.preparedMint(3).exists
                && core.tokenLifecycle(3) == uint8(StreamTokenLifecycle.UNKNOWN)
                && ledger.isManagerAuthorizationUsed(address(rescue), fresh.authorizationId)
                && ledger.isManagerNullifierUsed(address(rescue), gate.claimNullifier(claim)),
            "fresh prepared mint completes token4 serial4 without reusing gap or retaining sentinel"
        );
    }
}
