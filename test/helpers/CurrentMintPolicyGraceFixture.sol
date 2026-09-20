// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/domains/mint/StreamMintTicketGate.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintPolicyGrace.sol";

/// @dev Explicit external delivery fault; protocol contracts and Safe code remain original.
contract CurrentGraceRecipient {
    bool public accepting;

    function accept() external {
        accepting = true;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        require(accepting, "grace recipient rejects delivery");
        return this.onERC721Received.selector;
    }
}

/// @notice Actual Artist, Governor, ticket signer and executor Safes with current protocol code.
/// @dev The external entropy service is a double. The generic mint route is nonpayable;
/// the payer field authenticates metadata, not authority to spend that account's funds.
abstract contract CurrentMintPolicyGraceFixture is StreamCurrentSafeGovernanceFixture {
    bytes32 internal constant GRACE_PHASE = keccak256("actual current policy grace");
    bytes32 internal constant GRACE_COUNTER = keccak256("actual current grace beneficiary cap");
    bytes32 internal constant GRACE_VERSION = keccak256("actual current grace ticket version");
    bytes32 internal constant GRACE_MANIFEST = keccak256("actual current grace ticket manifest");
    bytes32 internal constant GRACE_CONTEXT = keccak256("original signed ticket under predecessor");
    OfficialSafe internal graceArtistSafe;
    OfficialSafe internal graceTicketSafe;
    OfficialSafe internal graceMintSafe;
    OfficialSafe internal graceNextSafe;
    OfficialSafe internal graceThirdSafe;
    StreamMintTicketGate internal graceGate;
    uint256[] internal graceKeys;

    function setUp() public virtual {
        graceKeys.push(0x5AFE01);
        graceKeys.push(0x5AFE02);
        SafeComponents memory c = deploySafeComponents("1.4.1");
        address[] memory owners = safeOwnerAddresses(graceKeys);
        graceArtistSafe = createOfficialSafe(c, owners, 2, 901);
        graceTicketSafe = createOfficialSafe(c, owners, 2, 902);
        graceMintSafe = createOfficialSafe(c, owners, 2, 903);
        graceNextSafe = createOfficialSafe(c, owners, 2, 904);
        graceThirdSafe = createOfficialSafe(c, owners, 2, 905);
        OfficialSafe nextGovernor = createOfficialSafe(c, owners, 2, 906);
        _deployCurrentStack(address(graceArtistSafe), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(nextGovernor, graceKeys);
        require(manager.owner() == address(executor), "actual governed Manager ownership");
        require(
            manager.supportsInterface(type(IStreamMintPolicyGrace).interfaceId)
                && manager.supportsInterface(type(IStreamMintManager).interfaceId),
            "additive grace and original Manager capabilities"
        );
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return
            safeThresholdSignature(
                graceKeys, safeMessageDigest(graceArtistSafe, abi.encode(digest))
            );
    }

    function _deployAdditionalProducts() internal override {
        graceGate = StreamMintTicketGate(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamMintTicketGate.sol:StreamMintTicketGate",
                abi.encode(address(executor), address(graceTicketSafe), uint8(2))
            )
        );
        _assertDeployableProductionInstance(address(graceGate));
    }

    function _configureAdditionalProducts() internal override {
        _admitGraceGate();
        (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gate,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory counters
        ) = _graceTerms();
        _recordGracePolicy(_gracePolicy(new address[](0)));
        manager.configurePhase(1, GRACE_PHASE, config, gate, ids, counters);
        _recordGracePolicy(_gracePolicy(_graceExecutors(1)));
        manager.setPhaseExecutor(1, GRACE_PHASE, address(graceMintSafe), true);
    }

    function _admitGraceGate() private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(graceGate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            GRACE_VERSION,
            type(IStreamMintGate).interfaceId,
            600_000,
            address(graceGate).codehash,
            DEPLOYMENT_HASH,
            GRACE_MANIFEST,
            "urn:stream:current:grace-ticket"
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
                    keccak256("current grace gate admission"),
                    "urn:stream:current:grace-ticket",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(result, (bytes32)), calls, data);
        StreamModuleRecord memory admitted = registry.moduleRecord(address(graceGate));
        require(
            admitted.status == ModuleRegistryStatus.ACTIVE
                && admitted.runtimeCodeHash == address(graceGate).codehash,
            "actual delayed gate admission"
        );
    }

    function _graceTerms()
        internal
        view
        returns (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gate,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory counters
        )
    {
        config = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            2,
            keccak256("grace immutable phase terms"),
            keccak256("grace phase metadata")
        );
        gate = IStreamMintManager.MintGateConfig(
            address(graceGate),
            graceGate.gateConfigHash(),
            address(graceGate).codehash,
            keccak256(abi.encode(GRACE_VERSION, GRACE_MANIFEST)),
            0,
            600_000
        );
        ids = new bytes32[](1);
        ids[0] = GRACE_COUNTER;
        counters = new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            keccak256("grace beneficiary cap two")
        );
    }

    function _graceExecutors(uint256 count) internal view returns (address[] memory enabled) {
        enabled = new address[](count);
        if (count > 0) enabled[0] = address(graceMintSafe);
        if (count > 1) enabled[1] = address(graceNextSafe);
        if (count > 2) enabled[2] = address(graceThirdSafe);
    }

    function _gracePolicy(address[] memory enabled) internal view returns (bytes32) {
        (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gate,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory counters
        ) = _graceTerms();
        return manager.previewPhasePolicyHash(1, GRACE_PHASE, config, gate, ids, counters, enabled);
    }

    /// @dev Derived scenarios choose an original direct or delegated Artist producer.
    function _recordGracePolicy(bytes32 policy) internal virtual {
        _recordFixturePolicy(GRACE_PHASE, policy);
    }

    function _rotationRequest(address changed, bool allowed, uint64 deadline)
        internal
        view
        returns (GovernanceActionRequest memory)
    {
        bytes memory data = abi.encodeCall(
            manager.setPhaseExecutorWithGrace, (1, GRACE_PHASE, changed, allowed, deadline)
        );
        return _governanceRequest(
            1,
            address(manager),
            data,
            keccak256(abi.encode(address(manager), data)),
            bytes32(0),
            keccak256(data)
        );
    }

    function _rotateGrace(address changed, bool allowed, address[] memory enabled, uint64 deadline)
        internal
        returns (bytes32 policy)
    {
        policy = _gracePolicy(enabled);
        _recordGracePolicy(policy);
        _govern(_rotationRequest(changed, allowed, deadline));
        require(manager.phasePolicyHash(1, GRACE_PHASE) == policy, "consented exact rotated policy");
        artists.requireMintConsent(1, GRACE_PHASE, policy);
    }

    function _graceRequest(uint256 nonce, OfficialSafe caller)
        internal
        view
        returns (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        )
    {
        batch.collectionId = 1;
        batch.phaseId = GRACE_PHASE;
        batch.payer = BUYER;
        batch.authorizer = address(graceTicketSafe);
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = address(caller);
        batch.beneficiaries = new address[](1);
        batch.beneficiaries[0] = address(caller);
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = TOKEN_DATA;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = keccak256(abi.encode("grace commitment", nonce));
        batch.expectedPolicyHash = manager.phasePolicyHash(1, GRACE_PHASE);
        batch.contextHash = GRACE_CONTEXT;
        ticket = _graceTicket(batch, caller, nonce);
        batch.authorizationId = manager.mintTicketAuthorizationId(ticket, address(graceGate));
    }

    function _graceTicket(IStreamMintManager.MintBatch memory b, OfficialSafe caller, uint256 nonce)
        internal
        view
        returns (StreamMintTicketTypes.MintTicket memory t)
    {
        t.chainId = block.chainid;
        t.manager = address(manager);
        t.ledger = address(ledger);
        t.collectionId = b.collectionId;
        t.phaseId = b.phaseId;
        t.executor = address(caller);
        t.payer = b.payer;
        t.authorizer = b.authorizer;
        t.authorizerKind = 2;
        t.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        t.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        t.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        t.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        t.quantity = b.initialRecipients.length;
        t.contextHash = b.contextHash;
        t.policyHash = b.expectedPolicyHash;
        t.nonce = bytes32(nonce);
        t.deadline = uint64(block.timestamp + 30 days);
    }

    function _graceProof(StreamMintTicketTypes.MintTicket memory ticket)
        internal
        returns (bytes memory)
    {
        bytes32 digest = StreamMintTicketHash.digest(block.chainid, address(graceGate), ticket);
        return abi.encode(
            ticket,
            safeThresholdSignature(
                graceKeys, safeMessageDigest(graceTicketSafe, abi.encode(digest))
            )
        );
    }

    function _graceMintCall(
        IStreamMintManager.MintBatch memory batch,
        bytes memory proof,
        bool prepared
    ) internal view returns (bytes memory) {
        return prepared
            ? abi.encodeCall(manager.executePreparedMint, (batch, proof))
            : abi.encodeCall(manager.executeSingleStepMint, (batch, proof));
    }

    function _graceSafeSignature(OfficialSafe caller, address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return safeThresholdSignature(
            graceKeys,
            caller.getTransactionHash(
                target, 0, data, 0, 0, 0, 0, address(0), address(0), caller.nonce()
            )
        );
    }

    function _graceSafeCall(
        OfficialSafe caller,
        address target,
        bytes memory data,
        bytes memory signature
    ) internal returns (bool) {
        return caller.execTransaction(
            target, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
    }

    function _graceSafeFailure(
        OfficialSafe caller,
        address target,
        bytes memory data,
        bytes memory signature
    ) internal {
        uint256 nonce = caller.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        _graceSafeCall(caller, target, data, signature);
        require(caller.nonce() == nonce, "failed Safe envelope preserves nonce");
    }

    function _graceMint(
        IStreamMintManager.MintBatch memory batch,
        bytes memory proof,
        bool prepared,
        OfficialSafe caller,
        bytes memory signature
    ) internal returns (bytes32 root) {
        bytes32 current = manager.phasePolicyHash(1, GRACE_PHASE);
        uint256 previousSupply = core.totalSupply();
        vm.recordLogs();
        require(
            _graceSafeCall(
                caller, address(manager), _graceMintCall(batch, proof, prepared), signature
            ),
            "original Safe mints"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 roots;
        uint256 authorizations;
        bytes32 authorizationRoot;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(ledger) || logs[i].topics.length != 4) continue;
            if (
                logs[i].topics[0]
                    == keccak256(
                        "MintLedgerOperationRootConsumed(uint16,bytes32,address,bytes32,bytes32,bytes32)"
                    )
            ) {
                ++roots;
                root = logs[i].topics[1];
                require(
                    address(uint160(uint256(logs[i].topics[2]))) == address(manager)
                        && logs[i].topics[3] == batch.expectedPolicyHash
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), current, batch.authorizationId)),
                    "exact distinct current and caller-bound policy receipt"
                );
            }
            if (
                logs[i].topics[0]
                    == keccak256(
                        "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"
                    )
            ) {
                ++authorizations;
                authorizationRoot = logs[i].topics[2];
                require(
                    logs[i].topics[1] == batch.authorizationId
                        && address(uint160(uint256(logs[i].topics[3]))) == address(manager)
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), batch.expectedPolicyHash)),
                    "authorization retains original signed bound hash"
                );
            }
        }
        require(
            roots == 1 && authorizations == 1 && root != 0 && authorizationRoot == root
                && manager.isOperationRootUsed(root)
                && ledger.isManagerAuthorizationUsed(address(manager), batch.authorizationId),
            "one canonical root and replay debit"
        );
        require(
            core.totalSupply() == previousSupply + batch.initialRecipients.length,
            "actual Core delivery"
        );
        require(
            graceTicketSafe.nonce() == 0 && graceArtistSafe.nonce() == 0,
            "ERC1271 verification consumes no signer Safe nonce"
        );
    }

    function _graceCounterKey(OfficialSafe beneficiary) internal view returns (bytes32) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            GRACE_PHASE,
            GRACE_COUNTER,
            BUYER,
            address(beneficiary),
            address(beneficiary),
            address(graceTicketSafe),
            GRACE_CONTEXT
        );
        return manager.previewCounterValueKey(1, GRACE_PHASE, GRACE_COUNTER, subject);
    }

    function _assertGrace(bytes32 previous, uint64 revision, uint64 deadline) internal view {
        (bytes32 actual, uint64 actualRevision, uint64 actualDeadline) =
            ledger.policyGrace(address(manager), 1, GRACE_PHASE);
        (bytes32 managerPrevious, uint64 managerDeadline) = manager.phasePolicyGrace(1, GRACE_PHASE);
        require(
            actual == previous && actualRevision == revision && actualDeadline == deadline
                && managerPrevious == previous && managerDeadline == deadline,
            "exact immediate predecessor and inclusive deadline"
        );
        require(
            ledger.registeredPhasePolicyHash(address(manager), 1, GRACE_PHASE)
                == manager.phasePolicyHash(1, GRACE_PHASE),
            "same registered current policy"
        );
    }
}
