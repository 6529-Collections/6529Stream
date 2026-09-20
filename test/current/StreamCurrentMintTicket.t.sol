// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../smart-contracts/domains/mint/StreamMintTicketGate.sol";
import "../../smart-contracts/domains/mint/StreamMintGateValidator.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintAuthorizationRevocation.sol";

/// @dev Explicit external recipient fault, with no replacement of protocol code or storage.
contract CurrentTicketRecipient {
    bool public accepting;

    function accept() external {
        accepting = true;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        require(accepting, "ticket recipient rejects delivery");
        return this.onERC721Received.selector;
    }
}

/// @notice Full current Artist/Core/Manager/Ledger composition for Safe-signed mint tickets.
/// @dev Only the external entropy service is a double. Artist consent, ticket ERC-1271 and
/// executor CALL use separate official threshold Safes. The typed payer field is not payment
/// authority: these two generic Manager entrypoints are nonpayable and perform no settlement.
contract StreamCurrentMintTicketTest is StreamCurrentStackFixture, OfficialSafeFixture {
    bytes32 private constant TICKET_PHASE = keccak256("current Safe ticket phase");
    bytes32 private constant COUNTER = keccak256("current Safe ticket recipient cap");
    bytes32 private constant GATE_VERSION = keccak256("current ticket gate v1");
    bytes32 private constant GATE_MANIFEST = keccak256("current ticket gate manifest");
    OfficialSafe private artistSafe;
    OfficialSafe private ticketSafe;
    OfficialSafe private executorSafe;
    StreamMintTicketGate private ticketGate;
    uint256[] private keys;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 701);
        ticketSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 702);
        executorSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 703);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _deployAdditionalProducts() internal override {
        ticketGate = StreamMintTicketGate(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamMintTicketGate.sol:StreamMintTicketGate",
                abi.encode(address(executor), address(ticketSafe), uint8(2))
            )
        );
        _assertDeployableProductionInstance(address(ticketGate));
    }

    function _configureAdditionalProducts() internal override {
        _admitTicketGate();
        IStreamMintManager.MintGateConfig memory gate = IStreamMintManager.MintGateConfig(
            address(ticketGate),
            ticketGate.gateConfigHash(),
            address(ticketGate).codehash,
            keccak256(abi.encode(GATE_VERSION, GATE_MANIFEST)),
            0,
            600_000
        );
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 2, keccak256("Safe ticket phase terms"), keccak256("Safe ticket metadata")
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            keccak256("Safe ticket recipient policy")
        );
        address[] memory enabled = new address[](0);
        _recordFixturePolicy(
            TICKET_PHASE,
            manager.previewPhasePolicyHash(1, TICKET_PHASE, config, gate, ids, counters, enabled)
        );
        manager.configurePhase(1, TICKET_PHASE, config, gate, ids, counters);
        enabled = new address[](1);
        enabled[0] = address(executorSafe);
        _recordFixturePolicy(
            TICKET_PHASE,
            manager.previewPhasePolicyHash(1, TICKET_PHASE, config, gate, ids, counters, enabled)
        );
        manager.setPhaseExecutor(1, TICKET_PHASE, address(executorSafe), true);
        artists.requireMintConsent(1, TICKET_PHASE, manager.phasePolicyHash(1, TICKET_PHASE));
    }

    function _admitTicketGate() private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(ticketGate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            GATE_VERSION,
            type(IStreamMintGate).interfaceId,
            600_000,
            address(ticketGate).codehash,
            DEPLOYMENT_HASH,
            GATE_MANIFEST,
            "urn:stream:fixture:current-safe-ticket"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        executor.publishGovernanceCallData(data);
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
                    keccak256("current Safe ticket admission"),
                    "urn:stream:fixture:current-safe-ticket",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(result, (bytes32)), calls, data);
        StreamModuleRecord memory admitted = registry.moduleRecord(address(ticketGate));
        require(
            admitted.status == ModuleRegistryStatus.ACTIVE
                && admitted.runtimeCodeHash == address(ticketGate).codehash,
            "actual delayed gate admission"
        );
    }

    function testActualSafeTicketSingleStepMintsRevealsAndRejectsExactReplay() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        ) = _request(1);
        bytes memory proof = _proof(ticket);
        vm.prank(address(executorSafe));
        (bytes32 preview, bytes32[] memory operations) =
            manager.previewSingleStepMintOperation(batch, proof);
        _assertUnconsumed(batch.authorizationId);
        bytes32 root = _mint(batch, proof, false);
        require(
            root == preview && operations.length == 1 && operations[0] != 0,
            "view preview binds the real executor and consumed root"
        );
        _expectReplay(batch, proof, false);
        (, uint256 requestId) = entropy.requestEntropy(1);
        provider.fulfill(requestId, keccak256("current Safe ticket entropy"));
        (, bool finalized) = entropy.tokenSeed(1);
        require(finalized && bytes(core.tokenURI(1)).length != 0, "actual reveal and metadata");
    }

    function testActualSafeTicketPreparedMintCompletesWithoutResidualPreparation() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        ) = _request(2);
        bytes memory proof = _proof(ticket);
        _mint(batch, proof, true);
        require(
            core.pendingPreparedMintTokenId() == 0 && !core.preparedMint(1).exists,
            "actual prepared mint completed in one transaction"
        );
        _expectReplay(batch, proof, true);
    }

    function testWrongSafeTicketSignatureAndPayloadTamperRejectBeforeOriginalPayloadMints() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        ) = _request(3);
        bytes32 digest = StreamMintTicketHash.digest(block.chainid, address(ticketGate), ticket);
        bytes memory wrongSafeProof = abi.encode(ticket, _artistProof(digest));
        vm.prank(address(executorSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintGateValidator.MintGateCallFailed.selector, address(ticketGate)
            )
        );
        manager.executeSingleStepMint(batch, wrongSafeProof);
        _expectSafeFailure(_mintCall(batch, wrongSafeProof, false));
        _assertUnconsumed(batch.authorizationId);
        bytes memory proof = _proof(ticket);
        batch.tokenData[0] = bytes("unsigned replacement artwork");
        vm.prank(address(executorSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintGateValidator.MintGateCallFailed.selector, address(ticketGate)
            )
        );
        manager.executeSingleStepMint(batch, proof);
        _expectSafeFailure(_mintCall(batch, proof, false));
        _assertUnconsumed(batch.authorizationId);
        batch.tokenData[0] = TOKEN_DATA;
        _mint(batch, proof, false);
    }

    function testSecondPreparedTicketDeliveryFailureRestoresWholeBatchAndIdenticalSafeRetry()
        public
    {
        CurrentTicketRecipient recipient = new CurrentTicketRecipient();
        (IStreamMintManager.MintBatch memory batch,) = _request(6);
        batch.initialRecipients = new address[](2);
        batch.initialRecipients[0] = address(executorSafe);
        batch.initialRecipients[1] = address(recipient);
        batch.beneficiaries = new address[](2);
        batch.beneficiaries[0] = address(executorSafe);
        batch.beneficiaries[1] = address(executorSafe);
        batch.tokenData = new bytes[](2);
        batch.tokenData[0] = TOKEN_DATA;
        batch.tokenData[1] = bytes("second signed ticket artwork");
        batch.mintCommitments = new bytes32[](2);
        batch.mintCommitments[0] = keccak256("first batch ticket commitment");
        batch.mintCommitments[1] = keccak256("second batch ticket commitment");
        StreamMintTicketTypes.MintTicket memory ticket = _ticket(batch, 6);
        batch.authorizationId = manager.mintTicketAuthorizationId(ticket, address(ticketGate));
        bytes memory data = _mintCall(batch, _proof(ticket), true);
        bytes32 digest = executorSafe.getTransactionHash(
            address(manager), 0, data, 0, 0, 0, 0, address(0), address(0), executorSafe.nonce()
        );
        bytes memory saved = abi.encodeCall(
            executorSafe.execTransaction,
            (
                address(manager),
                0,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        // recordLogs retains reverted trace entries; they are not committed receipt evidence.
        vm.recordLogs();
        (bool failed, bytes memory reason) = address(executorSafe).call(saved);
        require(
            !failed
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "late second delivery reverts the whole Safe envelope"
        );
        (bytes32 failedRoot, uint256 completed, bytes32 firstOperation) =
            _preparedTrace(vm.getRecordedLogs());
        require(
            failedRoot != 0 && completed == 1 && firstOperation != 0,
            "first actual token completed before second receiver failure"
        );
        _assertUnconsumed(batch.authorizationId);
        require(
            !manager.isOperationRootUsed(failedRoot)
                && !ledger.isManagerOperationRootUsed(address(manager), failedRoot)
                && core.collectionNextSerial(1) == 1 && core.pendingPreparedMintTokenId() == 0,
            "batch root and both allocations roll back"
        );
        for (uint256 tokenId = 1; tokenId <= 2; ++tokenId) {
            (bool exists,,,) = core.tokenCollectionIdentity(tokenId);
            require(
                !exists && !core.preparedMint(tokenId).exists && core.tokenData(tokenId).length == 0
                    && core.coordinatorAtMint(tokenId) == address(0),
                "no identity, content, preparation or entropy anchor survives"
            );
        }
        recipient.accept();
        vm.recordLogs();
        (bool ok, bytes memory result) = address(executorSafe).call(saved);
        require(ok && abi.decode(result, (bool)), "byte-identical signed Safe batch retries");
        (bytes32 root, uint256 count, bytes32 operation) = _preparedTrace(vm.getRecordedLogs());
        require(
            root == failedRoot && count == 2 && operation == firstOperation
                && manager.isOperationRootUsed(root)
                && manager.isAuthorizationUsed(batch.authorizationId),
            "same batch and first token identities commit once"
        );
        require(
            core.ownerOf(1) == address(executorSafe) && core.ownerOf(2) == address(recipient)
                && core.totalSupply() == 2 && core.collectionMintedEver(1) == 2
                && core.lastAllocatedTokenId() == 2 && core.collectionNextSerial(1) == 3
                && core.pendingPreparedMintTokenId() == 0 && manager.nextOperationNonce() == 2
                && ledger.counterValue(_counterKey()) == 2 && executorSafe.nonce() == 1,
            "both tokens and beneficiary debits commit atomically"
        );
        // The now-full cap rejects in transcript preparation, before Ledger's replay lookup.
        bytes memory proof = _proof(ticket);
        bytes32 counterKey = _counterKey();
        vm.prank(address(executorSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector, counterKey, uint256(4), uint256(2)
            )
        );
        manager.executePreparedMint(batch, proof);
        _expectSafeFailure(data);
        require(
            core.totalSupply() == 2 && manager.nextOperationNonce() == 2
                && ledger.counterValue(_counterKey()) == 2 && executorSafe.nonce() == 1
                && manager.isOperationRootUsed(root)
                && manager.isAuthorizationUsed(batch.authorizationId),
            "cap rejection preserves the committed receipt and both tokens"
        );
    }

    function _preparedTrace(Vm.Log[] memory logs)
        private
        view
        returns (bytes32 root, uint256 count, bytes32 first)
    {
        bytes32 previous;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(manager)
                    || logs[i].topics[0]
                        != keccak256(
                            "PreparedMintCompleted(uint16,bytes32,uint256,uint256,bytes32,address)"
                        )
            ) continue;
            (uint16 version, bytes32 operationRoot,) =
                abi.decode(logs[i].data, (uint16, bytes32, address));
            require(
                version == 1 && logs[i].topics[1] != 0 && logs[i].topics[1] != previous
                    && uint256(logs[i].topics[2]) == count + 1 && uint256(logs[i].topics[3]) == 1,
                "ordered distinct completed token operations"
            );
            if (count == 0) {
                root = operationRoot;
                first = logs[i].topics[1];
            }
            require(root == operationRoot, "one root for all completed tokens");
            previous = logs[i].topics[1];
            ++count;
        }
    }

    function testActualSafeDirectTicketVoidPreventsPreparedMintWithoutAccounting() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        ) = _request(4);
        bytes memory proof = _proof(ticket);
        require(
            executeSafe(
                ticketSafe,
                keys,
                address(manager),
                0,
                abi.encodeCall(manager.voidMintTicket, (ticket, address(ticketGate), bytes(""))),
                0
            ),
            "actual authorizer Safe voids its ticket"
        );
        require(ticketSafe.nonce() == 1, "direct void consumed only authorizer Safe nonce");
        _assertVoided(batch, proof);
    }

    function testActualSafeRelayedVoidRequiresSeparateRevocationSignature() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        ) = _request(5);
        bytes memory proof = _proof(ticket);
        (, bytes memory ticketSignature) =
            abi.decode(proof, (StreamMintTicketTypes.MintTicket, bytes));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector,
                address(ticketSafe)
            )
        );
        manager.voidMintTicket(ticket, address(ticketGate), ticketSignature);
        _assertUnconsumed(batch.authorizationId);
        bytes32 digest = keccak256(
            abi.encodePacked(
                hex"1901",
                StreamMintTicketHash.domain(block.chainid, address(ticketGate)),
                StreamMintTicketHash.revocationBody(
                    block.chainid, address(manager), address(ledger), batch.authorizationId
                )
            )
        );
        manager.voidMintTicket(
            ticket,
            address(ticketGate),
            safeThresholdSignature(keys, safeMessageDigest(ticketSafe, abi.encode(digest)))
        );
        require(
            ticketSafe.nonce() == 0, "ERC-1271 relayed void does not execute a Safe transaction"
        );
        _assertVoided(batch, proof);
    }

    function _request(uint256 nonce)
        private
        view
        returns (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        )
    {
        batch.collectionId = 1;
        batch.phaseId = TICKET_PHASE;
        batch.payer = BUYER;
        batch.authorizer = address(ticketSafe);
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = address(executorSafe);
        batch.beneficiaries = new address[](1);
        batch.beneficiaries[0] = address(executorSafe);
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = TOKEN_DATA;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = keccak256(abi.encode("current ticket commitment", nonce));
        batch.expectedPolicyHash = manager.phasePolicyHash(1, TICKET_PHASE);
        batch.contextHash = keccak256("separate Safe signer executor and typed payer");
        ticket = _ticket(batch, nonce);
        batch.authorizationId = manager.mintTicketAuthorizationId(ticket, address(ticketGate));
        require(
            batch.authorizationId
                == StreamMintTicketHash.authorizationId(
                    StreamMintTicketHash.digest(block.chainid, address(ticketGate), ticket)
                ),
            "positive ticket and revocation share exact full digest identity"
        );
    }

    function _ticket(IStreamMintManager.MintBatch memory batch, uint256 nonce)
        private
        view
        returns (StreamMintTicketTypes.MintTicket memory ticket)
    {
        ticket.chainId = block.chainid;
        ticket.manager = address(manager);
        ticket.ledger = address(ledger);
        ticket.collectionId = batch.collectionId;
        ticket.phaseId = batch.phaseId;
        ticket.executor = address(executorSafe);
        ticket.payer = batch.payer;
        ticket.authorizer = batch.authorizer;
        ticket.authorizerKind = 2;
        ticket.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), batch.initialRecipients)
        );
        ticket.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), batch.beneficiaries)
        );
        ticket.tokenDataArrayHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), batch.tokenData)
        );
        ticket.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), batch.mintCommitments)
        );
        ticket.quantity = batch.initialRecipients.length;
        ticket.contextHash = batch.contextHash;
        ticket.policyHash = batch.expectedPolicyHash;
        ticket.nonce = bytes32(nonce);
        ticket.deadline = uint64(block.timestamp + 1 days);
    }

    function _proof(StreamMintTicketTypes.MintTicket memory ticket) private returns (bytes memory) {
        bytes32 digest = StreamMintTicketHash.digest(block.chainid, address(ticketGate), ticket);
        return abi.encode(
            ticket, safeThresholdSignature(keys, safeMessageDigest(ticketSafe, abi.encode(digest)))
        );
    }

    function _mintCall(IStreamMintManager.MintBatch memory batch, bytes memory proof, bool prepared)
        private
        view
        returns (bytes memory)
    {
        return prepared
            ? abi.encodeCall(manager.executePreparedMint, (batch, proof))
            : abi.encodeCall(manager.executeSingleStepMint, (batch, proof));
    }

    function _mint(IStreamMintManager.MintBatch memory batch, bytes memory proof, bool prepared)
        private
        returns (bytes32 root)
    {
        vm.recordLogs();
        require(
            executeSafe(
                executorSafe, keys, address(manager), 0, _mintCall(batch, proof, prepared), 0
            ),
            "actual executor Safe mints"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 authorizations;
        uint256 batches;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(ledger)
                    && logs[i].topics[0]
                        == keccak256(
                            "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"
                        )
            ) {
                ++authorizations;
                root = logs[i].topics[2];
                require(
                    logs[i].topics[1] == batch.authorizationId
                        && address(uint160(uint256(logs[i].topics[3]))) == address(manager)
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), batch.expectedPolicyHash)),
                    "exact Ledger authorization evidence"
                );
            }
            if (
                logs[i].emitter == address(manager)
                    && logs[i].topics[0]
                        == keccak256(
                            "MintBatchExecuted(uint16,bytes32,uint256,bytes32,address,address,address,uint256,uint256,bytes32,bytes32,bytes32,bytes32)"
                        )
            ) {
                ++batches;
                require(
                    logs[i].topics[1] == root && uint256(logs[i].topics[2]) == 1
                        && logs[i].topics[3] == TICKET_PHASE,
                    "same Manager completion root and phase"
                );
            }
        }
        require(
            authorizations == 1 && batches == 1 && root != 0 && manager.isOperationRootUsed(root),
            "one durable batch root"
        );
        require(
            manager.isAuthorizationUsed(batch.authorizationId)
                && ledger.isManagerAuthorizationUsed(address(manager), batch.authorizationId),
            "exact ticket authorization consumed in canonical Ledger"
        );
        require(
            core.ownerOf(1) == address(executorSafe) && core.lastAllocatedTokenId() == 1
                && core.collectionMintedEver(1) == 1 && core.totalSupply() == 1
                && keccak256(core.tokenData(1)) == keccak256(TOKEN_DATA),
            "actual Core token and content"
        );
        require(
            manager.nextOperationNonce() == 1 && ledger.counterValue(_counterKey()) == 1
                && executorSafe.nonce() == 1 && ticketSafe.nonce() == 0,
            "one mint accounting debit and executor transaction; signature verification is read-only"
        );
    }

    function _counterKey() private view returns (bytes32) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            TICKET_PHASE,
            COUNTER,
            BUYER,
            address(executorSafe),
            address(executorSafe),
            address(ticketSafe),
            keccak256("separate Safe signer executor and typed payer")
        );
        return manager.previewCounterValueKey(1, TICKET_PHASE, COUNTER, subject);
    }

    function _assertUnconsumed(bytes32 authorization) private view {
        require(
            !manager.isAuthorizationUsed(authorization)
                && !ledger.isManagerAuthorizationUsed(address(manager), authorization),
            "failed or view authorization remains unconsumed"
        );
        _assertNoMint();
    }

    function _assertNoMint() private view {
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionMintedEver(1) == 0
                && core.totalSupply() == 0 && manager.nextOperationNonce() == 0
                && ledger.counterValue(_counterKey()) == 0 && executorSafe.nonce() == 0,
            "no Core allocation, counter debit, operation nonce or executor Safe nonce"
        );
    }

    function _assertVoided(IStreamMintManager.MintBatch memory batch, bytes memory proof) private {
        require(
            manager.isAuthorizationUsed(batch.authorizationId)
                && ledger.isManagerAuthorizationUsed(address(manager), batch.authorizationId),
            "void consumed exact ticket ID"
        );
        _assertNoMint();
        _expectReplay(batch, proof, true);
        _assertNoMint();
    }

    function _expectReplay(
        IStreamMintManager.MintBatch memory batch,
        bytes memory proof,
        bool prepared
    ) private {
        vm.prank(address(executorSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, batch.authorizationId
            )
        );
        if (prepared) manager.executePreparedMint(batch, proof);
        else manager.executeSingleStepMint(batch, proof);
        _expectSafeFailure(_mintCall(batch, proof, prepared));
    }

    function _expectSafeFailure(bytes memory data) private {
        uint256 nonce = executorSafe.nonce();
        bytes32 digest = executorSafe.getTransactionHash(
            address(manager), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signature = safeThresholdSignature(keys, digest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        executorSafe.execTransaction(
            address(manager), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(executorSafe.nonce() == nonce, "failed actual Safe envelope restores its nonce");
    }
}
